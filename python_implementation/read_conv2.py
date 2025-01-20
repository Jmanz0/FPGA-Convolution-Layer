def Read(file):
    """
    Reads a binary file and converts it to signed integers.
    :param file: Path to the binary file.
    :return: List of signed integers.
    """
    with open(file, 'rb') as f:
        arr = f.read()
        arr = [int(i) for i in arr]
        arr = [i if i < 128 else i - 256 for i in arr]  # Convert to signed 8-bit integers
    return arr

def Quant(num, Q):
    """
    Dequantizes a number using the quantization factor Q.
    :param num: Quantized integer.
    :param Q: Quantization factor (as in 2^Q).
    :return: Dequantized real number.
    """
    return num / (2 ** Q)  # Apply scaling factor for linear dequantization

def convert_conv2_binary_to_real(input_file, output_file, Q):
    """
    Reads the conv2.dat binary file, dequantizes the data using Q, 
    and writes the real numbers to a text file.
    :param input_file: Path to the binary file (e.g., conv2.dat).
    :param output_file: Path to the output plain text file.
    :param Q: Quantization factor (2^Q).
    """
    try:
        # Step 1: Read the binary data
        print(f"Reading binary file: {input_file}")
        int_data = Read(input_file)

        # Step 2: Dequantize the data using Q
        print(f"Dequantizing data with Q={Q}")
        real_data = [Quant(value, Q) for value in int_data]

        # Step 3: Write dequantized data to a plain text file
        print(f"Writing dequantized data to: {output_file}")
        with open(output_file, 'w') as f:
            for number in real_data:
                f.write(f"{number}\n")  # Write each dequantized number on a new line

        print(f"Conversion complete: {output_file}")
    except Exception as e:
        print(f"Error: {e}")

# Example usage for conv2
if __name__ == '__main__':
    input_file = './data/im1/conv2.output.dat'  # Path to conv2.dat file
    output_file = './data/im1/conv2.output.real.dat'  # Output file path
    Q = 8  # Quantization factor (Q_W for conv2 weights)
    convert_conv2_binary_to_real(input_file, output_file, Q)