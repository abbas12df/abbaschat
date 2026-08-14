from PIL import Image

def remove_green_screen(input_path, output_path):
    img = Image.open(input_path)
    img = img.convert("RGBA")
    datas = img.getdata()

    newData = []
    for item in datas:
        # Green Screen Logic: High Green, Low Red/Blue
        r, g, b, a = item
        
        # A simple check: if green is dominant
        if g > 150 and r < 100 and b < 100:
             newData.append((0, 0, 0, 0))
        else:
             newData.append(item)

    img.putdata(newData)
    img.save(output_path, "PNG")
    print(f"Saved chroma-keyed image to {output_path}")

if __name__ == "__main__":
    remove_green_screen("assets/images/nisaba_chroma_raw.png", "assets/images/nisaba_chroma_final.png")
