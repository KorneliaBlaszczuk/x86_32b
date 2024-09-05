#include <iostream>
#include <fstream>
using namespace std;

extern "C" int find_marker(unsigned char *bitmap, unsigned int *x_pos, unsigned int *y_pos);

int main(int argc, char *argv[]) {
    if (argc < 2) {
        cout << "Please specify input filepath" << endl;
        return 0;
    }

    streampos size;
    char *memblock;

    ifstream file(argv[1], ios::in | ios::binary | ios::ate);
    if (file.is_open()) {
        size = file.tellg();
        memblock = new char[size];
        file.seekg(0, ios::beg);
        file.read(memblock, size);
        file.close();
        cout << "File loaded into memory, extracting BMP dimensions..." << endl;

        cout << "Executing nasm function..." << endl;

        // Allocate memory for x and y positions
        unsigned int x_pos[50] = {0}; // Assuming max 100 markers
        unsigned int y_pos[50] = {0}; // Assuming max 100 markers

        int result = find_marker(reinterpret_cast<unsigned char*>(memblock), x_pos, y_pos);
        if (result < 0) { result = -1;}
        cout << "Result code: " << result << endl;

        if(result > 0) {
            for(int i = 0; i < result; i++) {
                cout << "Marker " << i+1 << " Position - X: " << x_pos[i] << ", Y: " << y_pos[i] << endl;
            }
        }

        cout << "Finished." << endl;

        delete[] memblock;
    } else {
        cout << "Unable to open specified file!" << endl;
    }
    return 0;
}
