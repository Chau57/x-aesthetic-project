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
}
