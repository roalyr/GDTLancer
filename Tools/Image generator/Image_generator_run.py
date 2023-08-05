import numpy as np
import tensorflow as tf
from tensorflow.keras.models import load_model
import cv2

# Load the trained generator model and generate
generator = load_model('crater_bump_maps_gray_30000.keras')
noise_dim = 100
output_shape = (256, 256, 1)  # Grayscale image shape 256x256 1bit
num_variations = 500

noise = np.random.normal(0.0, 1.0, (num_variations, noise_dim))
variations = generator.predict(noise)

# Denormalize and convert to integer values (0-255)
variations = (variations + 1) * 0.5  # Denormalize to [0, 1]
variations = (variations * 255).astype(np.uint8)

# Save or display variations
for i in range(num_variations):
    filename = f"./Generated_output/variation_{i}.png"
    cv2.imwrite(filename, variations[i][:, :, 0])  # Save grayscale image

print(f"{num_variations} variations saved.")
