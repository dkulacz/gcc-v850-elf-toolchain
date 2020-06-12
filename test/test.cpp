#include <vector>
#include <array>

auto get_value() { return 0.0; }

int main()
{
    std::vector<int> test_vec;
    std::array<int, 5> test_array{{3, 4, 5, 1, 2}};
    for (auto i : test_array)
        test_vec.push_back(i);
    double value = get_value();
    return 0;
}
