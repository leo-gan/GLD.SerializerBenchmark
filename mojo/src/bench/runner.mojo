from std.collections import List
from std.os import getenv
from std.sys import argv
from std.time import perf_counter_ns
from emberjson import parse
from bench.data import Cell, TypeConfig, fidelity, make_cell
from bench.schedule import record_run_order, shuffle, strategy
from bench.emberjson_ser import EmberJsonSer
from bench.ehsanmok_ser import EhsanJsonSer
from bench.cbor_ser import CborSer
from bench.avro_ser import AvroSer
from bench.protobuf_ser import ProtobufSer
from bench.toml_ser import TomlSer
from bench.gldjson_ser import GldJsonSer
from bench.yaml_ser import YamlSer
from bench.msgpack_ser import MsgpackSer


def _contains(hay: String, needle: String) -> Bool:
    if needle.byte_length() == 0:
        return True
    var h = hay.as_bytes()
    var n = needle.as_bytes()
    if len(n) > len(h):
        return False
    var i = 0
    while i <= len(h) - len(n):
        var ok = True
        var j = 0
        while j < len(n):
            var a = Int(h[i + j])
            var b = Int(n[j])
            if a >= 65 and a <= 90:
                a += 32
            if b >= 65 and b <= 90:
                b += 32
            if a != b:
                ok = False
                break
            j += 1
        if ok:
            return True
        i += 1
    return False


def _csv_escape(s: String) -> String:
    var need = False
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        if c == 44 or c == 34 or c == 10 or c == 13:
            need = True
            break
        i += 1
    if not need:
        return s
    var out = String('"')
    i = 0
    while i < len(b):
        if Int(b[i]) == 34:
            out += "\"\""
        else:
            out += String(chr(Int(b[i])))
        i += 1
    out += "\""
    return out^


def _ops(ns: Int) -> String:
    if ns <= 0:
        return ""
    var v = 1_000_000_000.0 / Float64(ns)
    return String(v)


def load_cells(path: String, data_filter: String) raises -> Tuple[UInt64, List[Cell], List[String]]:
    var text = open(path, "r").read()
    var root = parse(text)
    var seed = UInt64(42)
    try:
        seed = UInt64(Int(root.object()["seed"].int()))
    except:
        seed = UInt64(42)
    var cells = List[Cell]()
    var arr = root.object()["cells"].array().copy()
    var i = 0
    while i < len(arr):
        var o = arr[i].object().copy()
        var type_id = String(o["type_id"].string())
        if data_filter.byte_length() > 0 and not _contains(type_id, data_filter):
            i += 1
            continue
        var n = 1
        try:
            n = Int(o["data_type_instance_count"].int())
        except:
            n = 1
        var hash = ""
        try:
            hash = String(o["type_config_hash"].string())
        except:
            hash = ""
        var cfg = TypeConfig()
        try:
            var tc = o["type_config"].object().copy()
            try:
                cfg.children = Int(tc["children"].int())
            except:
                pass
            try:
                cfg.points = Int(tc["points"].int())
            except:
                pass
            try:
                cfg.count = Int(tc["count"].int())
            except:
                pass
            try:
                cfg.attr_count = Int(tc["attr_count"].int())
            except:
                pass
        except:
            pass
        cells.append(Cell(type_id, n, hash, cfg))
        i += 1
    var modes = List[String]()
    try:
        var marr = root.object()["execution"].object()["io_modes"].array().copy()
        var mi = 0
        while mi < len(marr):
            var m = String(marr[mi].string())
            if m == "bytes":
                modes.append(m)
            mi += 1
    except:
        modes.append("bytes")
    if len(modes) == 0:
        modes.append("bytes")
    return (seed, cells^, modes^)


def run() raises:
    var args = argv()
    var positional = List[String]()
    var ai = 1
    while ai < len(args):
        var a = String(args[ai])
        if a != "--":
            positional.append(a)
        ai += 1
    var reps = 2
    var ser_filter = ""
    var data_filter = ""
    if len(positional) > 0:
        reps = Int(positional[0])
    if len(positional) > 1:
        ser_filter = positional[1]
    if len(positional) > 2:
        data_filter = positional[2]

    var log_dir = String(getenv("LOG_DIR"))
    if log_dir.byte_length() == 0:
        log_dir = "logs/mojo"
    var ts = String(getenv("BENCHMARK_TS"))
    if ts.byte_length() == 0:
        ts = "run"
    var resolved = String(getenv("BENCHMARK_RESOLVED_JSON"))
    if resolved.byte_length() == 0:
        raise Error("BENCHMARK_RESOLVED_JSON is required")

    var loaded = load_cells(resolved, data_filter)
    var seed = loaded[0]
    var cells = loaded[1].copy()
    var modes = loaded[2].copy()
    try:
        var env_seed = String(getenv("BENCHMARK_SEED"))
        if env_seed.byte_length() > 0:
            seed = UInt64(Int(env_seed))
    except:
        pass

    var ember = EmberJsonSer()
    var ehsan = EhsanJsonSer()
    var cbor = CborSer()
    var avro = AvroSer()
    var proto = ProtobufSer()
    var toml = TomlSer()
    var gldj = GldJsonSer()
    var yaml = YamlSer()
    var msgp = MsgpackSer()
    var names = List[String]()
    names.append(ember.name())
    names.append(ehsan.name())
    names.append(cbor.name())
    names.append(avro.name())
    names.append(proto.name())
    names.append(toml.name())
    names.append(gldj.name())
    names.append(yaml.name())
    names.append(msgp.name())
    if ser_filter.byte_length() > 0:
        var filtered = List[String]()
        var ni = 0
        while ni < len(names):
            if _contains(names[ni], ser_filter):
                filtered.append(names[ni])
            ni += 1
        names = filtered^

    var header = String(
        "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,NativeKind,StreamMode,DataTypeInstanceCount,TypeConfigHash,RunOrder,SchedulePosition,SizeGzip,SizeZstd\n"
    )
    var lines = header
    var errors = String("TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n")
    var have_err = False
    var sched = strategy()
    var record_ro = record_run_order()
    var run_order = 0

    print(
        "[PROGRESS] Mojo Data Model v2:",
        len(names),
        "serializers,",
        len(cells),
        "cells,",
        reps,
        "reps, modes=bytes schedule=",
        sched,
    )

    var ci = 0
    while ci < len(cells):
        var cell = cells[ci].copy()
        var fx = make_cell(cell.type_id, cell.cfg, seed, cell.n, cell.hash)
        print("[PROGRESS] Testing Data:", fx.type_id, "(N=", fx.n, ")")
        var ready = List[String]()
        var ri = 0
        while ri < len(names):
            var nm = names[ri]
            try:
                if nm == ember.name():
                    _ = ember.serialize_bytes(fx)
                elif nm == ehsan.name():
                    _ = ehsan.serialize_bytes(fx)
                elif nm == cbor.name():
                    _ = cbor.serialize_bytes(fx)
                elif nm == avro.name():
                    _ = avro.serialize_bytes(fx)
                elif nm == proto.name():
                    _ = proto.serialize_bytes(fx)
                elif nm == gldj.name():
                    _ = gldj.serialize_bytes(fx)
                elif nm == yaml.name():
                    _ = yaml.serialize_bytes(fx)
                elif nm == msgp.name():
                    _ = msgp.serialize_bytes(fx)
                else:
                    _ = toml.serialize_bytes(fx)
                ready.append(nm)
            except e:
                print("[ERROR] prepare", nm, "/", fx.type_id, ":", String(e))
                errors += fx.type_id + "," + nm + ",prepare,0," + _csv_escape(String(e)) + "\n"
                have_err = True
            ri += 1

        var mi = 0
        while mi < len(modes):
            var mode = modes[mi]
            var rep = 0
            while rep < reps:
                var order = ready.copy()
                if sched != "none":
                    order = shuffle(ready, Int(seed), fx.type_id, fx.n, fx.hash, mode, rep)
                var pos = 0
                var oi = 0
                while oi < len(order):
                    var nm = order[oi]
                    pos += 1
                    run_order += 1
                    try:
                        var ser_ns: Int = 0
                        var deser_ns: Int = 0
                        var size: Int = 0
                        var ok = 1.0
                        var ver = ""
                        if nm == ember.name():
                            ver = ember.version
                            var t0 = Int(perf_counter_ns())
                            var buf = ember.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = ember.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = buf.byte_length()
                            if not fidelity(fx, back):
                                ok = 0.0
                        elif nm == ehsan.name():
                            ver = ehsan.version
                            var t0 = Int(perf_counter_ns())
                            var buf = ehsan.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = ehsan.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = buf.byte_length()
                            if not fidelity(fx, back):
                                ok = 0.0
                        elif nm == cbor.name():
                            ver = cbor.version
                            var t0 = Int(perf_counter_ns())
                            var buf = cbor.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = cbor.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = len(buf)
                            if not fidelity(fx, back):
                                ok = 0.0
                        elif nm == avro.name():
                            ver = avro.version
                            var t0 = Int(perf_counter_ns())
                            var buf = avro.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = avro.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = len(buf)
                            if not fidelity(fx, back):
                                ok = 0.0
                        elif nm == proto.name():
                            ver = proto.version
                            var t0 = Int(perf_counter_ns())
                            var buf = proto.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = proto.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = len(buf)
                            if not fidelity(fx, back):
                                ok = 0.0
                        elif nm == gldj.name():
                            ver = gldj.version
                            var t0 = Int(perf_counter_ns())
                            var buf = gldj.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = gldj.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = len(buf)
                            if not fidelity(fx, back):
                                ok = 0.0
                        elif nm == yaml.name():
                            ver = yaml.version
                            var t0 = Int(perf_counter_ns())
                            var buf = yaml.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = yaml.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = len(buf)
                            if not fidelity(fx, back):
                                ok = 0.0
                        elif nm == msgp.name():
                            ver = msgp.version
                            var t0 = Int(perf_counter_ns())
                            var buf = msgp.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = msgp.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = len(buf)
                            if not fidelity(fx, back):
                                ok = 0.0
                        else:
                            ver = toml.version
                            var t0 = Int(perf_counter_ns())
                            var buf = toml.serialize_bytes(fx)
                            var t1 = Int(perf_counter_ns())
                            var back = toml.deserialize_bytes(fx, buf)
                            var t2 = Int(perf_counter_ns())
                            ser_ns = t1 - t0
                            deser_ns = t2 - t1
                            size = buf.byte_length()
                            if not fidelity(fx, back):
                                ok = 0.0
                        if ok < 1.0:
                            errors += fx.type_id + "," + nm + "," + mode + "," + String(rep) + ",fidelity\n"
                            have_err = True
                        var tot = ser_ns + deser_ns
                        var ro = ""
                        if record_ro:
                            ro = String(run_order)
                        lines += (
                            "mojo,"
                            + mode
                            + ","
                            + fx.type_id
                            + ","
                            + String(reps)
                            + ","
                            + String(rep)
                            + ","
                            + nm
                            + ","
                            + ver
                            + ","
                            + String(ser_ns)
                            + ","
                            + String(deser_ns)
                            + ","
                            + String(size)
                            + ","
                            + String(tot)
                            + ","
                            + _ops(ser_ns)
                            + ","
                            + _ops(deser_ns)
                            + ","
                            + _ops(tot)
                            + ",0,"
                            + String(ok)
                            + ",message,,"
                            + String(fx.n)
                            + ","
                            + fx.hash
                            + ","
                            + ro
                            + ","
                            + String(pos)
                            + ",0,0\n"
                        )
                    except e:
                        print("[ERROR]", nm, "/", fx.type_id, "/", mode, ":", String(e))
                        errors += fx.type_id + "," + nm + "," + mode + "," + String(rep) + "," + _csv_escape(String(e)) + "\n"
                        have_err = True
                    oi += 1
                rep += 1
            mi += 1
        ci += 1

    var csv_path = log_dir + "/" + ts + ".csv"
    with open(csv_path, "w") as f:
        f.write(lines)
    if have_err:
        var err_path = log_dir + "/" + ts + ".errors.csv"
        with open(err_path, "w") as f:
            f.write(errors)
    print("[PROGRESS] Complete. Results:", csv_path)
