import os
import sys
import subprocess


def character_score(student_output: str, expected_output: str) -> float:
    """
    Scores output character-by-character.

    Returns:
        float in [0,1]
    """

    student_output = student_output.strip()
    expected_output = expected_output.strip()

    if len(expected_output) == 0:
        return 1.0 if len(student_output) == 0 else 0.0

    correct = 0

    min_len = min(len(student_output), len(expected_output))

    for i in range(min_len):
        if student_output[i] == expected_output[i]:
            correct += 1

    return correct / len(expected_output)


def check_output(student_file: str, expected_file: str) -> float:
    with open(student_file, "r") as f:
        student_output = f.read()

    with open(expected_file, "r") as f:
        expected_output = f.read()

    return character_score(student_output, expected_output)


def get_grade(executable: str, test_cases_folder: str) -> float:

    grade = 0
    number_of_test_cases = 0

    os.makedirs("my-outputs", exist_ok=True)

    subprocess.run(["make"], check=False)

    for input_file in sorted(os.listdir(test_cases_folder)):

        if not input_file.startswith("input"):
            continue

        output_file = input_file.replace("input", "output")

        input_path = os.path.join(test_cases_folder, input_file)
        expected_path = os.path.join(test_cases_folder, output_file)
        student_output_path = os.path.join("my-outputs", output_file)

        number_of_test_cases += 1

        try:
            with open(input_path, "r") as infile, \
                 open(student_output_path, "w") as outfile:

                subprocess.run(
                    [f"./{executable}"],
                    stdin=infile,
                    stdout=outfile,
                    stderr=subprocess.DEVNULL,
                    check=False
                )

            test_grade = check_output(student_output_path, expected_path)

        except Exception as e:
            print(e, file=sys.stderr)
            test_grade = 0.0

        grade += test_grade

        print(
            f"\033[93mtest-case '{input_file}': "
            f"{test_grade * 100:.2f} points\033[0m",
            file=sys.stderr
        )

    if number_of_test_cases == 0:
        return 0.0

    return grade * 100 / number_of_test_cases


if __name__ == '__main__':

    if len(sys.argv) != 3:
        print('Usage: python grader.py <executable> <test_cases_folder>')
        sys.exit(1)

    grade = get_grade(sys.argv[1], sys.argv[2])

    print(f'\033[92mGrade = {grade:.2f}\033[0m', file=sys.stderr)
    print(f'{grade:.2f}')
