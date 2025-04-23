import numpy as np

def sphere(distance, radius):
    return distance - radius

def generate_sdf_sphere(resolution, center, radius):
    """
    Generate a 3D texture representing the SDF of a sphere.

    Parameters:
        resolution (tuple): The resolution of the 3D grid (x, y, z).
        center (tuple): The center of the sphere (cx, cy, cz).
        radius (float): The radius of the sphere.

    Returns:
        numpy.ndarray: A 3D array containing the SDF values.
    """
    # Create a 3D grid of coordinates
    x = np.linspace(0, resolution[0] - 1, resolution[0])
    y = np.linspace(0, resolution[1] - 1, resolution[1])
    z = np.linspace(0, resolution[2] - 1, resolution[2])
    grid_x, grid_y, grid_z = np.meshgrid(x, y, z, indexing="ij")
    
    # Compute the distance of each grid point from the sphere center
    dx = grid_x - center[0]
    dy = grid_y - center[1]
    dz = grid_z - center[2]
    distance = np.sqrt(dx**2 + dy**2 + dz**2)

    # Compute the SDF values
    sdf = sphere(distance, radius)
    
    return sdf

# Parameters
resolution = (128, 128, 128)  # 3D grid resolution
center = (64, 64, 64)       # Center of the sphere
radius = 48                # Radius of the sphere

# Generate the SDF
sdf_texture = generate_sdf_sphere(resolution, center, radius)

# Save the SDF as a raw file
sdf_texture.astype(np.float32).tofile("../public/sdf_sphere.raw")

import matplotlib.pyplot as plt

# Visualize the middle slice along the z-axis
slice_index = resolution[2] // 2
plt.imshow(sdf_texture[:, :, slice_index], cmap="viridis")
plt.colorbar(label="Signed Distance")
plt.title("SDF Sphere (Slice)")
plt.show()

