package com.example.x_aesthetic_app

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import android.util.Rational

class MainActivity : FlutterActivity() {
    private val channelName = "x_aesthetic/hardware_hdr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isHardwareHdrSupported" -> result.success(isHardwareHdrSupported(call.lensDirection()))
                "captureHardwareHdr" -> captureHardwareHdr(call, result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "x_aesthetic/pro_camera").setMethodCallHandler { call, result ->
            when (call.method) {
                "captureProPhoto" -> captureProPhoto(call, result)
                "setHardwareFocus" -> setHardwareFocus(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun MethodCall.lensDirection(): String {
        return argument<String>("lensDirection") ?: "back"
    }

    private fun requestedFacing(lensDirection: String): Int {
        return when (lensDirection) {
            "front" -> CameraCharacteristics.LENS_FACING_FRONT
            "external" -> CameraCharacteristics.LENS_FACING_EXTERNAL
            else -> CameraCharacteristics.LENS_FACING_BACK
        }
    }

    private fun isHardwareHdrSupported(lensDirection: String): Boolean {
        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val requestedFacing = requestedFacing(lensDirection)
        return try {
            cameraManager.cameraIdList.any { cameraId ->
                val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                characteristics.get(CameraCharacteristics.LENS_FACING) == requestedFacing && characteristics.supportsHdrSceneMode()
            }
        } catch (_: CameraAccessException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun captureHardwareHdr(call: MethodCall, result: MethodChannel.Result) {
        if (!hasCameraPermission()) {
            result.error("camera_permission_missing", "Ứng dụng chưa có quyền camera.", null)
            return
        }

        val outputPath = call.argument<String>("outputPath")
        if (outputPath.isNullOrBlank()) {
            result.error("invalid_output_path", "Không có đường dẫn để lưu ảnh HDR.", null)
            return
        }

        val lensDirection = call.lensDirection()
        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = try {
            findCameraId(cameraManager, lensDirection)
        } catch (error: Exception) {
            result.error("camera_not_found", error.message ?: "Không tìm thấy camera phù hợp.", null)
            return
        }

        val characteristics = try {
            cameraManager.getCameraCharacteristics(cameraId)
        } catch (error: Exception) {
            result.error("camera_characteristics_error", error.message ?: "Không đọc được thông tin camera.", null)
            return
        }

        if (!characteristics.supportsHdrSceneMode()) {
            result.error("hardware_hdr_not_supported", "Camera hiện tại chưa báo hỗ trợ CONTROL_SCENE_MODE_HDR.", null)
            return
        }

        val size = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            ?.getOutputSizes(ImageFormat.JPEG)
            ?.maxByOrNull { it.width.toLong() * it.height.toLong() }

        if (size == null) {
            result.error("jpeg_size_unavailable", "Không tìm được kích thước JPEG cho camera.", null)
            return
        }

        val replied = AtomicBoolean(false)
        val cameraThread = HandlerThread("X-Aesthetic-Hardware-HDR").apply { start() }
        val cameraHandler = Handler(cameraThread.looper)
        var imageReader: ImageReader? = null
        var cameraDevice: CameraDevice? = null
        var captureSession: CameraCaptureSession? = null
        var previewTexture: SurfaceTexture? = null
        var previewSurface: Surface? = null

        fun cleanup() {
            try { captureSession?.close() } catch (_: Exception) {}
            try { cameraDevice?.close() } catch (_: Exception) {}
            try { imageReader?.close() } catch (_: Exception) {}
            try { previewSurface?.release() } catch (_: Exception) {}
            try { previewTexture?.release() } catch (_: Exception) {}
            cameraThread.quitSafely()
        }

        fun sendError(code: String, message: String, details: Any? = null) {
            if (replied.compareAndSet(false, true)) {
                cleanup()
                result.error(code, message, details)
            }
        }

        fun sendSuccess(path: String) {
            if (replied.compareAndSet(false, true)) {
                cleanup()
                result.success(path)
            }
        }

        val reader = ImageReader.newInstance(size.width, size.height, ImageFormat.JPEG, 1)
        imageReader = reader

        // Camera2 still capture can return an underexposed/black JPEG on some devices
        // if the 3A pipeline (auto exposure/auto focus/auto white balance) has not
        // had time to converge. A small dummy preview surface lets the camera run a
        // normal repeating request before we trigger the HDR still capture.
        val texture = SurfaceTexture(0).apply { setDefaultBufferSize(1280, 720) }
        previewTexture = texture
        val surface = Surface(texture)
        previewSurface = surface

        cameraHandler.postDelayed({
            if (!replied.get()) {
                sendError("capture_timeout", "Native HDR không trả ảnh sau thời gian chờ.")
            }
        }, 8000L)

        reader.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage()
            if (image == null) {
                sendError("image_unavailable", "Không nhận được ảnh HDR từ native camera.")
                return@setOnImageAvailableListener
            }

            try {
                val buffer = image.planes[0].buffer
                val bytes = ByteArray(buffer.remaining())
                buffer.get(bytes)
                val outputFile = File(outputPath)
                outputFile.parentFile?.mkdirs()
                FileOutputStream(outputFile).use { it.write(bytes) }
                image.close()
                sendSuccess(outputFile.absolutePath)
            } catch (error: Exception) {
                image.close()
                sendError("save_failed", error.message ?: "Không lưu được ảnh HDR.")
            }
        }, cameraHandler)

        try {
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    try {
                        camera.createCaptureSession(
                            listOf(surface, reader.surface),
                            object : CameraCaptureSession.StateCallback() {
                                override fun onConfigured(session: CameraCaptureSession) {
                                    captureSession = session
                                    try {
                                        val previewRequest = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                                            addTarget(surface)
                                            set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_USE_SCENE_MODE)
                                            set(CaptureRequest.CONTROL_SCENE_MODE, CaptureRequest.CONTROL_SCENE_MODE_HDR)
                                            set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                                            set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                                            set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
                                        }
                                        session.setRepeatingRequest(previewRequest.build(), null, cameraHandler)

                                        cameraHandler.postDelayed({
                                            try {
                                                val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                                                    addTarget(reader.surface)
                                                    set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_USE_SCENE_MODE)
                                                    set(CaptureRequest.CONTROL_SCENE_MODE, CaptureRequest.CONTROL_SCENE_MODE_HDR)
                                                    set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                                                    set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                                                    set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
                                                    set(CaptureRequest.JPEG_ORIENTATION, jpegOrientation(characteristics))
                                                }
                                                session.capture(request.build(), object : CameraCaptureSession.CaptureCallback() {
                                                    override fun onCaptureFailed(session: CameraCaptureSession, request: CaptureRequest, failure: android.hardware.camera2.CaptureFailure) {
                                                        sendError("capture_failed", "Native HDR capture failed: ${failure.reason}")
                                                    }
                                                }, cameraHandler)
                                            } catch (error: Exception) {
                                                sendError("capture_request_failed", error.message ?: "Không tạo được yêu cầu chụp HDR.")
                                            }
                                        }, 900L)
                                    } catch (error: Exception) {
                                        sendError("preview_request_failed", error.message ?: "Không khởi động được preview native trước khi chụp HDR.")
                                    }
                                }

                                override fun onConfigureFailed(session: CameraCaptureSession) {
                                    sendError("session_config_failed", "Không cấu hình được phiên chụp HDR native.")
                                }
                            },
                            cameraHandler
                        )
                    } catch (error: Exception) {
                        sendError("session_create_failed", error.message ?: "Không tạo được Camera2 session.")
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    sendError("camera_disconnected", "Camera bị ngắt kết nối khi chụp HDR.")
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    sendError("camera_error", "Camera2 báo lỗi khi chụp HDR: $error")
                }
            }, cameraHandler)
        } catch (error: Exception) {
            sendError("open_camera_failed", error.message ?: "Không mở được camera để chụp HDR.")
        }
    }

    private fun hasCameraPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun findCameraId(cameraManager: CameraManager, lensDirection: String): String {
        val requestedFacing = requestedFacing(lensDirection)
        return cameraManager.cameraIdList.firstOrNull { cameraId ->
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            characteristics.get(CameraCharacteristics.LENS_FACING) == requestedFacing
        } ?: throw IllegalStateException("Không tìm thấy camera $lensDirection.")
    }

    private fun CameraCharacteristics.supportsHdrSceneMode(): Boolean {
        val modes = get(CameraCharacteristics.CONTROL_AVAILABLE_SCENE_MODES) ?: return false
        return modes.contains(CaptureRequest.CONTROL_SCENE_MODE_HDR)
    }

    private fun jpegOrientation(characteristics: CameraCharacteristics): Int {
        val sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
        val rotation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.rotation
        }
        val deviceOrientation = when (rotation) {
            Surface.ROTATION_90 -> 90
            Surface.ROTATION_180 -> 180
            Surface.ROTATION_270 -> 270
            else -> 0
        }
        val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
        return if (facing == CameraCharacteristics.LENS_FACING_FRONT) {
            (sensorOrientation + deviceOrientation) % 360
        } else {
            (sensorOrientation - deviceOrientation + 360) % 360
        }
    }

    @SuppressLint("MissingPermission")
    private fun captureProPhoto(call: MethodCall, result: MethodChannel.Result) {
        if (!hasCameraPermission()) {
            result.error("camera_permission_missing", "Ứng dụng chưa có quyền camera.", null)
            return
        }

        val outputPath = call.argument<String>("outputPath")
        if (outputPath.isNullOrBlank()) {
            result.error("invalid_output_path", "Không có đường dẫn để lưu ảnh.", null)
            return
        }

        val lensDirection = call.lensDirection()
        val wb = call.argument<String>("wb") ?: "Auto"
        val focus = call.argument<String>("focus") ?: "Auto"
        val speed = call.argument<String>("speed") ?: "Auto"
        val iso = call.argument<String>("iso") ?: "Auto"
        val exposureOffset = call.argument<Double>("exposureOffset") ?: 0.0

        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = try {
            findCameraId(cameraManager, lensDirection)
        } catch (error: Exception) {
            result.error("camera_not_found", error.message ?: "Không tìm thấy camera phù hợp.", null)
            return
        }

        val characteristics = try {
            cameraManager.getCameraCharacteristics(cameraId)
        } catch (error: Exception) {
            result.error("camera_characteristics_error", error.message ?: "Không đọc được thông tin camera.", null)
            return
        }

        val size = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            ?.getOutputSizes(ImageFormat.JPEG)
            ?.maxByOrNull { it.width.toLong() * it.height.toLong() }

        if (size == null) {
            result.error("jpeg_size_unavailable", "Không tìm được kích thước JPEG cho camera.", null)
            return
        }

        val replied = AtomicBoolean(false)
        val cameraThread = HandlerThread("X-Aesthetic-Pro-Capture").apply { start() }
        val cameraHandler = Handler(cameraThread.looper)
        var imageReader: ImageReader? = null
        var cameraDevice: CameraDevice? = null
        var captureSession: CameraCaptureSession? = null
        var previewTexture: SurfaceTexture? = null
        var previewSurface: Surface? = null

        fun cleanup() {
            try { captureSession?.close() } catch (_: Exception) {}
            try { cameraDevice?.close() } catch (_: Exception) {}
            try { imageReader?.close() } catch (_: Exception) {}
            try { previewSurface?.release() } catch (_: Exception) {}
            try { previewTexture?.release() } catch (_: Exception) {}
            cameraThread.quitSafely()
        }

        fun sendError(code: String, message: String, details: Any? = null) {
            if (replied.compareAndSet(false, true)) {
                cleanup()
                result.error(code, message, details)
            }
        }

        fun sendSuccess(path: String) {
            if (replied.compareAndSet(false, true)) {
                cleanup()
                result.success(path)
            }
        }

        val reader = ImageReader.newInstance(size.width, size.height, ImageFormat.JPEG, 1)
        imageReader = reader

        val texture = SurfaceTexture(0).apply { setDefaultBufferSize(1280, 720) }
        previewTexture = texture
        val surface = Surface(texture)
        previewSurface = surface

        cameraHandler.postDelayed({
            if (!replied.get()) {
                sendError("capture_timeout", "Native Pro capture không trả ảnh sau thời gian chờ.")
            }
        }, 8000L)

        reader.setOnImageAvailableListener({ reader ->
            val image = reader.acquireLatestImage()
            if (image == null) {
                sendError("image_unavailable", "Không nhận được ảnh từ native camera.")
                return@setOnImageAvailableListener
            }

            try {
                val buffer = image.planes[0].buffer
                val bytes = ByteArray(buffer.remaining())
                buffer.get(bytes)
                val outputFile = File(outputPath)
                outputFile.parentFile?.mkdirs()
                FileOutputStream(outputFile).use { it.write(bytes) }
                image.close()
                sendSuccess(outputFile.absolutePath)
            } catch (error: Exception) {
                image.close()
                sendError("save_failed", error.message ?: "Không lưu được ảnh Pro.")
            }
        }, cameraHandler)

        fun applyProParameters(builder: CaptureRequest.Builder) {
            try {
                if (wb.endsWith("K")) {
                    val kelvin = wb.replace("K", "").toIntOrNull() ?: 5500
                    if (kelvin <= 3500) {
                        builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_INCANDESCENT)
                    } else if (kelvin <= 4500) {
                        builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_FLUORESCENT)
                    } else if (kelvin <= 6500) {
                        builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_DAYLIGHT)
                    } else {
                        builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_CLOUDY_DAYLIGHT)
                    }
                } else {
                    when (wb) {
                        "Sunny" -> {
                            builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_DAYLIGHT)
                        }
                        "Cloudy" -> {
                            builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_CLOUDY_DAYLIGHT)
                        }
                        "Incandescent" -> {
                            builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_INCANDESCENT)
                        }
                        "Fluorescent" -> {
                            builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_FLUORESCENT)
                        }
                        else -> {
                            builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
                        }
                    }
                }

                if (focus == "Auto") {
                    builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                } else {
                    builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
                    var focusVal = focus.toFloatOrNull() ?: 1.0f
                    if (focusVal > 1.0f) {
                        focusVal /= 100.0f
                    }
                    val minFocus = characteristics.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
                    if (minFocus > 0.0f) {
                        val diopter = (1.0f - focusVal) * minFocus
                        builder.set(CaptureRequest.LENS_FOCUS_DISTANCE, diopter)
                    } else {
                        builder.set(CaptureRequest.LENS_FOCUS_DISTANCE, 0.0f)
                    }
                }

                val isSpeedManual = speed != "Auto"
                val isIsoManual = iso != "Auto"

                if (isSpeedManual || isIsoManual) {
                    builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)

                    if (isSpeedManual) {
                        val speedNs = parseSpeedToNanoseconds(speed)
                        if (speedNs > 0) {
                            val range = characteristics.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
                            if (range != null) {
                                builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, speedNs.coerceIn(range.lower, range.upper))
                            } else {
                                builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, speedNs)
                            }
                        }
                    } else {
                        builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, 1000000000L / 60L)
                    }

                    if (isIsoManual) {
                        val isoVal = iso.toIntOrNull()
                        if (isoVal != null) {
                            val range = characteristics.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
                            if (range != null) {
                                builder.set(CaptureRequest.SENSOR_SENSITIVITY, isoVal.coerceIn(range.lower, range.upper))
                            } else {
                                builder.set(CaptureRequest.SENSOR_SENSITIVITY, isoVal)
                            }
                        }
                    } else {
                        builder.set(CaptureRequest.SENSOR_SENSITIVITY, 200)
                    }
                } else {
                    builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                    val compensationRange = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
                    val step = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
                    if (compensationRange != null && step != null) {
                        val stepValue = step.numerator.toDouble() / step.denominator.toDouble()
                        if (stepValue > 0.0) {
                            val steps = (exposureOffset / stepValue).toInt().coerceIn(compensationRange.lower, compensationRange.upper)
                            builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, steps)
                        }
                    }
                }
            } catch (e: Exception) {
                // Defensive
            }
        }

        try {
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    try {
                        camera.createCaptureSession(
                            listOf(surface, reader.surface),
                            object : CameraCaptureSession.StateCallback() {
                                override fun onConfigured(session: CameraCaptureSession) {
                                    captureSession = session
                                    try {
                                        val previewRequest = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                                            addTarget(surface)
                                            applyProParameters(this)
                                        }
                                        session.setRepeatingRequest(previewRequest.build(), null, cameraHandler)

                                        cameraHandler.postDelayed({
                                            try {
                                                val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                                                    addTarget(reader.surface)
                                                    applyProParameters(this)
                                                    set(CaptureRequest.JPEG_ORIENTATION, jpegOrientation(characteristics))
                                                }
                                                session.capture(request.build(), object : CameraCaptureSession.CaptureCallback() {
                                                    override fun onCaptureFailed(session: CameraCaptureSession, request: CaptureRequest, failure: android.hardware.camera2.CaptureFailure) {
                                                        sendError("capture_failed", "Native Pro capture failed: ${failure.reason}")
                                                    }
                                                }, cameraHandler)
                                            } catch (error: Exception) {
                                                sendError("capture_request_failed", error.message ?: "Không tạo được yêu cầu chụp Pro.")
                                            }
                                        }, 900L)
                                    } catch (error: Exception) {
                                        sendError("preview_request_failed", error.message ?: "Không khởi động được preview native trước khi chụp Pro.")
                                    }
                                }

                                override fun onConfigureFailed(session: CameraCaptureSession) {
                                    sendError("session_config_failed", "Không cấu hình được phiên chụp Pro native.")
                                }
                            },
                            cameraHandler
                        )
                    } catch (error: Exception) {
                        sendError("session_create_failed", error.message ?: "Không tạo được Camera2 session.")
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    sendError("camera_disconnected", "Camera bị ngắt kết nối khi chụp Pro.")
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    sendError("camera_error", "Camera2 báo lỗi khi chụp Pro: $error")
                }
            }, cameraHandler)
        } catch (error: Exception) {
            sendError("open_camera_failed", error.message ?: "Không mở được camera để chụp Pro.")
        }
    }

    private fun parseSpeedToNanoseconds(speedStr: String): Long {
        return try {
            if (speedStr.contains("/")) {
                val parts = speedStr.split("/")
                val denominator = parts[1].replace("s", "").trim().toDouble()
                val numerator = parts[0].trim().toDouble()
                ((numerator / denominator) * 1000000000L).toLong()
            } else {
                val seconds = speedStr.replace("s", "").trim().toDouble()
                (seconds * 1000000000L).toLong()
            }
        } catch (e: Exception) {
            0L
        }
    }

    private fun setHardwareFocus(call: MethodCall, result: MethodChannel.Result) {
        val lensDirection = call.argument<String>("lensDirection") ?: "back"
        val focus = call.argument<String>("focus") ?: "Auto"
        android.util.Log.d("ProCamera", "=== setHardwareFocus called: focus=$focus, lens=$lensDirection ===")

        try {
            val engine = flutterEngine
            if (engine == null) {
                android.util.Log.e("ProCamera", "FlutterEngine is NULL - cannot apply focus")
                result.success(null)
                return
            }
            android.util.Log.d("ProCamera", "FlutterEngine OK, searching for CameraControl...")
            val cameraControl = findCameraControl(engine)
            if (cameraControl == null) {
                android.util.Log.e("ProCamera", "CameraControl is NULL - focus NOT applied! Camera may not be initialized yet.")
                result.success(null)
                return
            }
            android.util.Log.d("ProCamera", "CameraControl found: ${cameraControl.javaClass.name}")

            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = findCameraId(cameraManager, lensDirection)
            android.util.Log.d("ProCamera", "Using cameraId=$cameraId")
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)

            if (focus == "Auto") {
                android.util.Log.d("ProCamera", "Applying AUTO focus mode")
                applyHardwareAutoFocus(cameraControl)
            } else {
                val focusVal = focus.toFloatOrNull() ?: 1.0f
                android.util.Log.d("ProCamera", "Applying MANUAL focus: focusVal=$focusVal")
                applyHardwareFocus(cameraControl, focusVal, characteristics)
            }
            result.success(null)
        } catch (e: Exception) {
            android.util.Log.e("ProCamera", "Error setting hardware focus: ${e.message}", e)
            result.error("focus_error", e.message, null)
        }
    }

    private fun findCameraControl(flutterEngine: FlutterEngine): Any? {
        try {
            val pluginClass = Class.forName("io.flutter.plugins.camerax.CameraAndroidCameraxPlugin")
            android.util.Log.d("ProCamera", "Plugin class found: ${pluginClass.name}")
            val plugin = flutterEngine.plugins.get(pluginClass as Class<out io.flutter.embedding.engine.plugins.FlutterPlugin>)
            if (plugin == null) {
                android.util.Log.e("ProCamera", "CameraAndroidCameraxPlugin not registered in FlutterEngine!")
                return null
            }
            android.util.Log.d("ProCamera", "Plugin instance found: ${plugin.javaClass.name}")

            // Helper: collect ALL declared fields from a class and ALL its superclasses
            fun getAllFields(clazz: Class<*>): List<java.lang.reflect.Field> {
                val result = mutableListOf<java.lang.reflect.Field>()
                var c: Class<*>? = clazz
                while (c != null && c != Any::class.java) {
                    result.addAll(c.declaredFields)
                    c = c.superclass
                }
                return result
            }

            // Helper: check if an object is a CameraControl or Camera, return CameraControl if found
            fun checkObject(obj: Any?): Any? {
                if (obj == null) return null
                val objClass = obj.javaClass
                val isCameraControl = try {
                    Class.forName("androidx.camera.core.CameraControl").isInstance(obj)
                } catch (_: Exception) { objClass.name.contains("CameraControl") }
                if (isCameraControl) {
                    android.util.Log.d("ProCamera", "    checkObject: CameraControl found: ${objClass.name}")
                    return obj
                }
                val isCamera = try {
                    Class.forName("androidx.camera.core.Camera").isInstance(obj)
                } catch (_: Exception) {
                    objClass.name.contains("Camera") &&
                    !objClass.name.contains("CameraControl") &&
                    !objClass.name.contains("CameraInfo") &&
                    !objClass.name.contains("CameraDevice") &&
                    !objClass.name.contains("CameraManager") &&
                    !objClass.name.contains("CameraCharacteristics")
                }
                if (isCamera) {
                    android.util.Log.d("ProCamera", "    checkObject: Camera found: ${objClass.name}, calling getCameraControl()")
                    return try {
                        val ctrl = objClass.getMethod("getCameraControl").invoke(obj)
                        android.util.Log.d("ProCamera", "    getCameraControl() = ${ctrl?.javaClass?.name}")
                        ctrl
                    } catch (e1: Exception) {
                        try {
                            val ctrl = Class.forName("androidx.camera.core.Camera")
                                .getMethod("getCameraControl").invoke(obj)
                            android.util.Log.d("ProCamera", "    getCameraControl() via iface = ${ctrl?.javaClass?.name}")
                            ctrl
                        } catch (e2: Exception) {
                            android.util.Log.e("ProCamera", "    getCameraControl() failed: ${e2.message}")
                            null
                        }
                    }
                }
                return null
            }

            // Helper: given an InstanceManager-like object, search its collections for Camera/CameraControl
            fun searchInstanceManager(im: Any): Any? {
                android.util.Log.d("ProCamera", "  searchInstanceManager: ${im.javaClass.name}")
                for (f in getAllFields(im.javaClass)) {
                    f.isAccessible = true
                    val value = try { f.get(im) } catch (_: Exception) { null } ?: continue
                    android.util.Log.d("ProCamera", "    IM field '${f.name}': ${value.javaClass.simpleName}")
                    if (value is Map<*, *>) {
                        android.util.Log.d("ProCamera", "    Map size=${value.size}")
                        for (entry in value.entries) {
                            val resK = checkObject(entry.key); if (resK != null) return resK
                            val resV = checkObject(entry.value); if (resV != null) return resV
                        }
                    }
                    val vName = value.javaClass.name
                    if (vName.contains("LongSparseArray") || vName.contains("SparseArray")) {
                        try {
                            val size = value.javaClass.getMethod("size").invoke(value) as Int
                            val valueAt = value.javaClass.getMethod("valueAt", Int::class.java)
                            android.util.Log.d("ProCamera", "    SparseArray size=$size")
                            for (i in 0 until size) {
                                val res = checkObject(valueAt.invoke(value, i))
                                if (res != null) return res
                            }
                        } catch (e: Exception) {
                            android.util.Log.w("ProCamera", "    SparseArray iteration failed: ${e.message}")
                        }
                    }
                }
                return null
            }

            // Recursively find InstanceManager in object graph up to maxDepth levels
            val visited = mutableSetOf<Int>() // track by identity hash to avoid cycles
            fun findIM(obj: Any, depth: Int = 0): Any? {
                if (depth > 3) return null
                val id = System.identityHashCode(obj)
                if (!visited.add(id)) return null
                val fields = getAllFields(obj.javaClass)
                android.util.Log.d("ProCamera", "D$depth [${obj.javaClass.simpleName}] fields: ${fields.map { it.name + ":" + it.type.simpleName }}")
                // First pass: look for InstanceManager directly
                for (field in fields) {
                    val typeName = field.type.name
                    val fieldName = field.name.lowercase()
                    if (typeName.contains("InstanceManager") || fieldName == "instancemanager" || fieldName == "pigeoninstancemanager") {
                        field.isAccessible = true
                        val im = try { field.get(obj) } catch (_: Exception) { null } ?: continue
                        android.util.Log.d("ProCamera", "D$depth Found InstanceManager '${field.name}': ${im.javaClass.name}")
                        val result = searchInstanceManager(im)
                        if (result != null) return result
                    }
                }
                // Second pass: recurse into Flutter/CameraX-related fields
                for (field in fields) {
                    val typeName = field.type.name
                    if (typeName.startsWith("io.flutter") || typeName.startsWith("io.flutter.plugins.camerax") ||
                        typeName.contains("Registrar") || typeName.contains("ProxyApi")) {
                        field.isAccessible = true
                        val value = try { field.get(obj) } catch (_: Exception) { null } ?: continue
                        android.util.Log.d("ProCamera", "D$depth Recursing into '${field.name}': ${value.javaClass.name}")
                        val result = findIM(value, depth + 1)
                        if (result != null) return result
                    }
                }
                return null
            }


            val instanceManager: Any? = null  // unused sentinel; actual search via findIM below

            // Run the recursive search from the plugin root
            val result = findIM(plugin)
            if (result != null) return result
            android.util.Log.e("ProCamera", "CameraControl not found anywhere in plugin graph!")
        } catch (e: Exception) {
            android.util.Log.e("ProCamera", "Failed to find CameraControl: ${e.message}", e)
        }
        return null
    }


    private fun applyHardwareFocus(cameraControl: Any, focusVal: Float, characteristics: CameraCharacteristics) {
        try {
            val minFocus = characteristics.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 0.0f
            // focusVal: 0=infinity(far), 1=closest. Diopter: 0=infinity, minFocus=closest.
            // focusVal=0 → diopter=0 (infinity), focusVal=1 → diopter=minFocus (closest)
            val diopter = focusVal * minFocus
            android.util.Log.d("ProCamera", "applyHardwareFocus: focusVal=$focusVal, minFocus=$minFocus, diopter=$diopter")
            android.util.Log.d("ProCamera", "CameraControl class: ${cameraControl.javaClass.name}")
            
            // Use CaptureRequestOptions.Builder (correct API)
            val optionsBuilderClass = Class.forName("androidx.camera.camera2.interop.CaptureRequestOptions\$Builder")
            android.util.Log.d("ProCamera", "CaptureRequestOptions.Builder found")
            val optionsBuilder = optionsBuilderClass.getDeclaredConstructor().newInstance()
            
            val setOptionMethod = optionsBuilderClass.getMethod("setCaptureRequestOption", CaptureRequest.Key::class.java, Any::class.java)
            
            // Set AF Mode to OFF to prevent autofocus from overriding our value
            setOptionMethod.invoke(optionsBuilder, CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
            android.util.Log.d("ProCamera", "Set CONTROL_AF_MODE = OFF")
            
            // Set Lens Focus Distance
            setOptionMethod.invoke(optionsBuilder, CaptureRequest.LENS_FOCUS_DISTANCE, diopter)
            android.util.Log.d("ProCamera", "Set LENS_FOCUS_DISTANCE = $diopter")
            
            val buildMethod = optionsBuilderClass.getMethod("build")
            val options = buildMethod.invoke(optionsBuilder)
            android.util.Log.d("ProCamera", "CaptureRequestOptions built: ${options?.javaClass?.name}")
            
            // Get Camera2CameraControl from CameraControl
            val interopClass = Class.forName("androidx.camera.camera2.interop.Camera2CameraControl")
            val fromMethod = interopClass.getMethod("from", Class.forName("androidx.camera.core.CameraControl"))
            android.util.Log.d("ProCamera", "Calling Camera2CameraControl.from() on ${cameraControl.javaClass.name}")
            val camera2Control = fromMethod.invoke(null, cameraControl)
            android.util.Log.d("ProCamera", "camera2Control: ${camera2Control?.javaClass?.name}")
            
            val setOptionsMethod = camera2Control!!.javaClass.getMethod("setCaptureRequestOptions",
                Class.forName("androidx.camera.camera2.interop.CaptureRequestOptions"))
            val future = setOptionsMethod.invoke(camera2Control, options)
            android.util.Log.d("ProCamera", "setCaptureRequestOptions() returned: ${future?.javaClass?.name}")
            
            android.util.Log.d("ProCamera", "=== Hardware focus APPLIED: focusVal=$focusVal, diopter=$diopter (AF=OFF) ===")
        } catch (e: Exception) {
            android.util.Log.e("ProCamera", "Failed to apply hardware focus: ${e.message}", e)
        }
    }

    private fun applyHardwareAutoFocus(cameraControl: Any) {
        try {
            android.util.Log.d("ProCamera", "applyHardwareAutoFocus: restoring CONTINUOUS_PICTURE AF mode")
            
            // Use CaptureRequestOptions.Builder (correct API)
            val optionsBuilderClass = Class.forName("androidx.camera.camera2.interop.CaptureRequestOptions\$Builder")
            val optionsBuilder = optionsBuilderClass.getDeclaredConstructor().newInstance()
            
            val setOptionMethod = optionsBuilderClass.getMethod("setCaptureRequestOption", CaptureRequest.Key::class.java, Any::class.java)
            
            // Set AF Mode to CONTINUOUS_PICTURE
            setOptionMethod.invoke(optionsBuilder, CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            
            val buildMethod = optionsBuilderClass.getMethod("build")
            val options = buildMethod.invoke(optionsBuilder)
            
            val interopClass = Class.forName("androidx.camera.camera2.interop.Camera2CameraControl")
            val fromMethod = interopClass.getMethod("from", Class.forName("androidx.camera.core.CameraControl"))
            val camera2Control = fromMethod.invoke(null, cameraControl)
            
            val setOptionsMethod = camera2Control!!.javaClass.getMethod("setCaptureRequestOptions",
                Class.forName("androidx.camera.camera2.interop.CaptureRequestOptions"))
            setOptionsMethod.invoke(camera2Control, options)
            
            android.util.Log.d("ProCamera", "=== Hardware autofocus RESTORED ===")
        } catch (e: Exception) {
            android.util.Log.e("ProCamera", "Failed to restore hardware autofocus: ${e.message}", e)
        }
    }
}
