import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:x_aesthetic_app/services/ai/local_ai_engine.dart';

void main() {
  test('LocalAiEngine end-to-end classification and advice generation',
      () async {
    final ai = LocalAiEngine.instance;

    print("Initializing LocalAiEngine...");
    await ai.init();
    expect(ai.isInitialized, isTrue);
    print("LocalAiEngine initialized successfully!");

    print("Creating dummy image...");
    final dummy = img.Image(width: 224, height: 224);
    // Draw some pixels
    for (var i = 0; i < 224; i++) {
      dummy.setPixel(i, i, img.ColorRgb8(255, 200, 150));
    }

    print("Classifying image...");
    final category = await ai.classifyImage(dummy);
    print("ResNet18 classification output category: $category");
    expect(category, isNotEmpty);

    print("Generating advice from Gemma-3...");
    final advice = await ai.generateAdvice(category, 0.45, 250.0);
    print("Gemma-3 generated advice: $advice");
    expect(advice, isNotEmpty);

    print("Disposing LocalAiEngine...");
    await ai.dispose();
  });
}
