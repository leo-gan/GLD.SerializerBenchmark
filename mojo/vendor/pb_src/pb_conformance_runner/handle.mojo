from std.collections import List

from conformance import (
    ConformanceRequest,
    ConformanceResponse,
    FailureSet,
    WireFormat_PROTOBUF,
)
from protobuf import DecodeError
from protobuf_test_messages.proto3 import TestAllTypesProto3


comptime MSG_PROTO3 = "protobuf_test_messages.proto3.TestAllTypesProto3"
comptime MSG_FAILURE_SET = "conformance.FailureSet"


def handle_request(req: ConformanceRequest) -> ConformanceResponse:
    var resp = ConformanceResponse()
    if req.message_type == MSG_FAILURE_SET:
        var fs = FailureSet()
        resp.which_result = 3
        resp.protobuf_payload = fs.encode()
        return resp^
    if req.message_type != MSG_PROTO3:
        resp.which_result = 5
        resp.skipped = "only protobuf_test_messages.proto3.TestAllTypesProto3"
        return resp^
    if req.requested_output_format.value != WireFormat_PROTOBUF:
        resp.which_result = 5
        resp.skipped = "only binary protobuf output"
        return resp^
    if req.which_payload != 1:
        resp.which_result = 5
        resp.skipped = "only binary protobuf input"
        return resp^
    try:
        var msg = TestAllTypesProto3.decode(req.protobuf_payload)
        resp.which_result = 3
        resp.protobuf_payload = msg.encode()
    except e:
        resp.which_result = 1
        resp.parse_error = String(e)
    return resp^
