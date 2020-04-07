""" Unit tests to cover the Arduino Station module."""
import unittest
from piws import arduino_station

TEMP_C = 100
TEMP_F = 212.0

class ChartsTests(unittest.TestCase):

    def test_convert_c_to_f_returns_expected_type(self):
        result = arduino_station.convert_c_to_f(TEMP_C)
        expected = float
        self.assertEqual(expected, type(result))

    def test_convert_c_to_f_returns_correct_temp_F_value(self):
        result = arduino_station.convert_c_to_f(TEMP_C)
        expected = TEMP_F
        self.assertEqual(expected, result)
