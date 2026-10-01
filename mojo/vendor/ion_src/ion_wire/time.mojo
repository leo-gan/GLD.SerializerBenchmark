from ion_runtime.doc import IonTime
from ion_runtime.error import DecodeError


def _dim(year: Int, month: Int) -> Int:
    if month == 2:
        if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
            return 29
        return 28
    if month == 4 or month == 6 or month == 9 or month == 11:
        return 30
    return 31


def shift_days(mut when: IonTime, days: Int) raises DecodeError:
    """Move `when` by `days`. The year stays inside 1..999999999."""
    var left = days
    while left > 0:
        var dim = _dim(when.year, when.month)
        var room = dim - when.day
        if left <= room:
            when.day += left
            return
        left -= room + 1
        when.day = 1
        when.month += 1
        if when.month == 13:
            when.month = 1
            when.year += 1
            if when.year > 999999999:
                raise DecodeError(DecodeError.KIND_RANGE, 0)
    while left < 0:
        if when.day - 1 >= 0 - left:
            when.day += left
            return
        left += when.day
        when.month -= 1
        if when.month == 0:
            when.month = 12
            when.year -= 1
            if when.year < 1:
                raise DecodeError(DecodeError.KIND_RANGE, 0)
        when.day = _dim(when.year, when.month)


def apply_offset(mut when: IonTime, minutes: Int) raises DecodeError:
    """Add `minutes` to a minute-or-finer timestamp. Year, month, and day values are left alone."""
    if when.prec < 3:
        return
    var total = when.hour * 60 + when.minute + minutes
    var days = 0
    while total < 0:
        total += 1440
        days -= 1
    while total >= 1440:
        total -= 1440
        days += 1
    when.hour = total // 60
    when.minute = total % 60
    if days != 0:
        shift_days(when, days)
