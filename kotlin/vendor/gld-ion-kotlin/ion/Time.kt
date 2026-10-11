package ion

internal fun daysInMonth(year: Int, month: Int): Int {
    if (month == 2) {
        val leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        return if (leap) 29 else 28
    }
    if (month == 4 || month == 6 || month == 9 || month == 11) return 30
    return 31
}

internal fun shiftDays(whenTime: IonTime, days: Int) {
    var left = days
    while (left > 0) {
        val dim = daysInMonth(whenTime.year, whenTime.month)
        val room = dim - whenTime.day
        if (left <= room) {
            whenTime.day += left
            return
        }
        left -= room + 1
        whenTime.day = 1
        whenTime.month++
        if (whenTime.month == 13) {
            whenTime.month = 1
            whenTime.year++
            if (whenTime.year > 999999999) throw DecodeError(DecodeError.KIND_RANGE, 0)
        }
    }
    while (left < 0) {
        if (whenTime.day - 1 >= -left) {
            whenTime.day += left
            return
        }
        left += whenTime.day
        whenTime.month--
        if (whenTime.month == 0) {
            whenTime.month = 12
            whenTime.year--
            if (whenTime.year < 1) throw DecodeError(DecodeError.KIND_RANGE, 0)
        }
        whenTime.day = daysInMonth(whenTime.year, whenTime.month)
    }
}

/** Add [minutes] to a minute-or-finer timestamp. Coarser values are left alone. */
internal fun applyOffset(whenTime: IonTime, minutes: Int) {
    if (whenTime.prec < PREC_MIN) return
    var total = whenTime.hour * 60 + whenTime.minute + minutes
    var days = 0
    while (total < 0) {
        total += 1440
        days--
    }
    while (total >= 1440) {
        total -= 1440
        days++
    }
    whenTime.hour = total / 60
    whenTime.minute = total % 60
    if (days != 0) shiftDays(whenTime, days)
}
