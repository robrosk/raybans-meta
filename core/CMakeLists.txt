cmake_minimum_required(VERSION 3.16)
project(raybans-core CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(rbcore
    src/session_engine.cpp
)
target_include_directories(rbcore PUBLIC include)

add_executable(rbcore_tests tests/test_session_engine.cpp)
target_link_libraries(rbcore_tests PRIVATE rbcore)

enable_testing()
add_test(NAME rbcore_tests COMMAND rbcore_tests)
