from PIL import Image

def remove_white_bg(input_path, output_path):
    img = Image.open(input_path)
    img = img.convert("RGBA")
    datas = img.getdata()

    newData = []
    for item in datas:
        # Check if pixel is white (or very close to white)
        # RGB > 240, 240, 240 is a safe threshold for white background
        if item[0] > 240 and item[1] > 240 and item[2] > 240:
            newData.append((255, 255, 255, 0)) # Make it transparent
        else:
            newData.append(item)

    img.putdata(newData)
    img.save(output_path, "PNG")
    print(f"Saved transparent image to {output_path}")

if __name__ == "__main__":
    remove_white_bg("assets/images/nisaba_v3.png", "assets/images/nisaba_welcome_transparent.png")
