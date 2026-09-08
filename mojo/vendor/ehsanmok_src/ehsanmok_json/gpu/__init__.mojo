# GPU backends require Modular `max`. This harness times the default
# CPU parser only, so the GPU symbols are stubs that raise if selected.

from ..types import JSONInput
from ..value import Value


def parse_json_gpu(input_obj: JSONInput) raises -> Int:
    raise Error("ehsanmok-json GPU target is not built in this harness")


def parse_json_gpu_from_pinned(input_obj: JSONInput) raises -> Int:
    raise Error("ehsanmok-json GPU target is not built in this harness")


def parse_gpu_to_value(s: String, result: Int) raises -> Value:
    raise Error("ehsanmok-json GPU target is not built in this harness")
