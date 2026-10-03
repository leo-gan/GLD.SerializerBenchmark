package benchmark.model.v2

/** Shared row-list and table_project helpers. */
object V2Rows {
    fun tables(value: Any?): List<TableRow> {
        if (value is TableRow) return listOf(value)
        val list = value as List<*>
        return List(list.size) { list[it] as TableRow }
    }

    fun nested(value: Any?): List<NestedRow> {
        if (value is NestedRow) return listOf(value)
        val list = value as List<*>
        return List(list.size) { list[it] as NestedRow }
    }

    fun signals(value: Any?): List<Signal> {
        if (value is Signal) return listOf(value)
        val list = value as List<*>
        return List(list.size) { list[it] as Signal }
    }

    /** f_float_0 column. N=1 is a one-element list, not a scalar. */
    fun float0(decoded: Any?): List<Double> {
        if (decoded is TableRow) return listOf(decoded.fFloat0)
        if (decoded is List<*>) {
            return decoded.map { o ->
                when (o) {
                    is TableRow -> o.fFloat0
                    is Number -> o.toDouble()
                    else -> error("cannot project ${o?.javaClass?.name}")
                }
            }
        }
        error("cannot project ${decoded?.javaClass?.name}")
    }

    fun oneOrList(rows: List<*>, batch: Boolean): Any {
        if (!batch) {
            if (rows.isEmpty()) error("empty batch")
            return rows[0]!!
        }
        return rows
    }
}
