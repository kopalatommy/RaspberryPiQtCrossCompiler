#include <iostream>
#include <filesystem>

int main() {
    for(auto &file : std::filesystem::recursive_directory_iterator("./")) {
        std::cout << file.path() << '\n';
    }
}