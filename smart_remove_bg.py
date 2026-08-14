from PIL import Image
import sys

def smart_remove_bg(input_path, output_path, tolerance=30):
    img = Image.open(input_path)
    img = img.convert("RGBA")
    width, height = img.size
    pixels = img.load()

    # Visited set for BFS
    visited = set()
    queue = []

    # Seed corners
    corners = [(0, 0), (width-1, 0), (0, height-1), (width-1, height-1)]
    
    for x, y in corners:
        r, g, b, a = pixels[x, y]
        # Only start if corner is relatively dark (assumes black background)
        if r < tolerance and g < tolerance and b < tolerance:
            queue.append((x, y))
            visited.add((x, y))

    # Directions: 4-connected
    directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

    while queue:
        x, y = queue.pop(0)
        
        # Set current pixel to transparent
        pixels[x, y] = (0, 0, 0, 0)

        # Check neighbors
        for dx, dy in directions:
            nx, ny = x + dx, y + dy
            
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in visited:
                nr, ng, nb, na = pixels[nx, ny]
                # Check if neighbor is close to black/background color
                if nr < tolerance and ng < tolerance and nb < tolerance:
                    visited.add((nx, ny))
                    queue.append((nx, ny))

    # Optional: Feathering/Anti-aliasing (Simple alpha fade for border pixels)
    # This is a bit expensive in pure python, so we skip for now, 
    # but the flood fill should prevent internal holes.

    img.save(output_path, "PNG")
    print(f"Processed image saved to {output_path}")

if __name__ == "__main__":
    # Using tolerance 40 to catch compression artifacts/gradients
    smart_remove_bg("assets/images/nisaba_welcome.png", "assets/images/nisaba_clean.png", tolerance=40)
