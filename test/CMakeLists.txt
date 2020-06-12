cmake_minimum_required(VERSION 3.10)

project(rh850_test_build)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(FLAGS)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${FLAGS}")
endif()

add_executable(rh850_test_c test.c)

add_executable(rh850_test_cpp test.cpp)
