from PIL import Image

def remove_black_bg(input_path, output_path):
    img = Image.open(input_path)
    img = img.convert("RGBA")
    datas = img.getdata()

    newData = []
    for item in datas:
        # Check if pixel is black (or very close to black)
        # RGB < 15, 15, 15 is a safe threshold for deep black
        if item[0] < 20 and item[1] < 20 and item[2] < 20:
            newData.append((0, 0, 0, 0)) # Make it transparent
        else:
            newData.append(item)

    img.putdata(newData)
    img.save(output_path, "PNG")
    print(f"Saved transparent image to {output_path}")

if __name__ == "__main__":
    remove_black_bg("assets/images/nisaba_welcome.png", "assets/images/nisaba_final.png")
