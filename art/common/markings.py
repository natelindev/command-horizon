"""Small, neutral mechanical emblems for the procedural model generators."""

from math import cos, sin, tau


def service_gear(x, y, z, size=1.0, depth=.025):
    """Return a small toothed ring with an open center, facing positive Y."""
    count = 48
    outer = [.25 if index % 4 in (1, 2) else .215 for index in range(count)]
    vertices = [
        (x + radius * size * cos(index * tau / count), side_y,
         z + radius * size * sin(index * tau / count))
        for side_y in (y - depth / 2, y + depth / 2)
        for radii in (outer, [.105] * count)
        for index, radius in enumerate(radii)
    ]
    faces = []
    for index in range(count):
        following = (index + 1) % count
        faces.extend([
            (index, following, following + count, index + count),
            (index + count * 2, index + count * 3,
             following + count * 3, following + count * 2),
            (index, index + count * 2, following + count * 2, following),
            (index + count, following + count,
             following + count * 3, index + count * 3),
        ])
    return vertices, faces
