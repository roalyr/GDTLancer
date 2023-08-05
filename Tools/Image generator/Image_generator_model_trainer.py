import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
import os
import cv2

# Define parameters
model_name = 'crater_bump_maps_gray'
batch_size = 4 # Optimal (?) for 24 input training images
epochs = 100000
model_save_interval = 1000
sample_interval = 10
input_shape = (256, 256, 1)  # Grayscale image shape 256x256 1bit
output_shape = (256, 256, 1)  # Grayscale image shape 256x256 1bit
noise_dim = 100

# Constants
temporary_images = "./Temporary/"
training_image_dir = "./Data_for_training/"
model_path = './Models/'
model_format = '.keras'


# Build the Generator
def build_generator():
    model = models.Sequential()
    model.add(layers.Dense(128, input_dim=noise_dim))
    model.add(layers.LeakyReLU(alpha=0.2))
    model.add(layers.Dense(256))
    model.add(layers.LeakyReLU(alpha=0.2))
    model.add(layers.Dense(np.prod(output_shape), activation='tanh'))  # Output shape matches grayscale images
    model.add(layers.Reshape(output_shape))  # Reshape to image dimensions
    return model

# Build the Discriminator
def build_discriminator():
    model = models.Sequential()
    model.add(layers.Flatten(input_shape=output_shape))  # Input shape matches grayscale images
    model.add(layers.Dense(256))
    model.add(layers.LeakyReLU(alpha=0.2))
    model.add(layers.Dense(128))
    model.add(layers.LeakyReLU(alpha=0.2))
    model.add(layers.Dense(1, activation='sigmoid'))
    return model


# Build GAN
generator = build_generator()
discriminator = build_discriminator()
discriminator.compile(loss='binary_crossentropy', optimizer='adam', metrics=['accuracy'])
discriminator.trainable = False
gan_input = layers.Input(shape=(noise_dim,))
generated_image = generator(gan_input)
gan_output = discriminator(generated_image)
gan = models.Model(gan_input, gan_output)
gan.compile(loss='binary_crossentropy', optimizer='adam')

# Load and preprocess image data
def load_and_preprocess_images(training_image_dir):
    images = []
    for filename in os.listdir(training_image_dir):
        img = cv2.imread(os.path.join(training_image_dir, filename), cv2.IMREAD_GRAYSCALE)
        img = cv2.resize(img, (input_shape[1], input_shape[0]))
        img = img / 255.0  # Normalize to [0, 1]
        img = np.expand_dims(img, axis=-1)  # Add channel dimension
        images.append(img)
    return np.array(images)



X_train = load_and_preprocess_images(training_image_dir)

# Function to save a single generated image
def save_generated_image(epoch, generator, filename):
    noise = np.random.normal(0, 1, (1, noise_dim))  # Generate noise for a single image
    generated_image = generator.predict(noise)[0]   # Generate the image
    generated_image = (generated_image + 1) * 0.5   # Denormalize
    generated_image = (generated_image * 255).astype(np.uint8)  # Convert to uint8
    cv2.imwrite(filename, generated_image)

for epoch in range(epochs):
    # Train discriminator
    idx = np.random.randint(0, X_train.shape[0], batch_size)
    real_images = X_train[idx]
    noise = np.random.normal(0, 1, (batch_size, noise_dim))
    fake_images = generator.predict(noise)
    d_loss_real = discriminator.train_on_batch(real_images, np.ones((batch_size, 1)))
    d_loss_fake = discriminator.train_on_batch(fake_images, np.zeros((batch_size, 1)))
    d_loss = 0.5 * np.add(d_loss_real, d_loss_fake)

    # Train generator
    noise = np.random.normal(0, 1, (batch_size, noise_dim))
    g_loss = gan.train_on_batch(noise, np.ones((batch_size, 1)))

    # Print progress and save generated images
    if epoch % sample_interval == 0:
        print(f"Epoch {epoch}, D Loss: {d_loss[0]}, G Loss: {g_loss}")
        # Save generated images
        filename = temporary_images + 'epoch_' + str(epoch) + ".png"
        save_generated_image(epoch, generator, filename)
    
    if epoch % model_save_interval == 0:
	    generator.save(model_path + model_name + '_' + str(epoch) + model_format)
	    filename = model_path + model_name + '_' +str(epoch) + ".png"
	    save_generated_image(epoch, generator, filename)

# Save the trained generator model
# generator.save(model_name + model_format)
