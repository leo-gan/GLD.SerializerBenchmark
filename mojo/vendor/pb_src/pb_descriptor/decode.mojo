from std.collections import List, Optional, Span

from pb_descriptor.model import (
    EnumDesc,
    EnumValueDesc,
    FieldDesc,
    FileDesc,
    FileDescSet,
    MessageDesc,
    OneofDesc,
    TYPE_MESSAGE,
)
from pb_runtime.error import DecodeError
from pb_wire.reader import WireReader
from pb_wire.size import u64_to_i32
from pb_wire.types import WireType


def _read_bool[origin: ImmOrigin](mut dec: WireReader[origin]) raises DecodeError -> Bool:
    return dec.read_varint() != 0


def _merge_field_options[
    origin: ImmOrigin
](mut packed: Optional[Bool], mut dec: WireReader[origin]) raises DecodeError:
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 2 and wire == WireType.VARINT:
            packed = _read_bool(dec)
        else:
            dec.skip_field(wire)


def _merge_message_options[
    origin: ImmOrigin
](mut map_entry: Bool, mut dec: WireReader[origin]) raises DecodeError:
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 7 and wire == WireType.VARINT:
            map_entry = _read_bool(dec)
        else:
            dec.skip_field(wire)


def _merge_enum_value[
    origin: ImmOrigin
](mut value: EnumValueDesc, mut dec: WireReader[origin]) raises DecodeError:
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 1 and wire == WireType.LEN:
            value.name = dec.read_string()
        elif field == 2 and wire == WireType.VARINT:
            value.number = u64_to_i32(dec.read_varint())
        else:
            dec.skip_field(wire)


def _merge_enum[
    origin: ImmOrigin
](mut enum: EnumDesc, mut dec: WireReader[origin]) raises DecodeError:
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 1 and wire == WireType.LEN:
            enum.name = dec.read_string()
        elif field == 2 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            var value = EnumValueDesc()
            _merge_enum_value(value, inner)
            enum.values.append(value^)
        else:
            dec.skip_field(wire)


def _merge_oneof[
    origin: ImmOrigin
](mut oneof: OneofDesc, mut dec: WireReader[origin]) raises DecodeError:
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 1 and wire == WireType.LEN:
            oneof.name = dec.read_string()
        else:
            dec.skip_field(wire)


def _merge_field[
    origin: ImmOrigin
](mut field_desc: FieldDesc, mut dec: WireReader[origin]) raises DecodeError:
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 1 and wire == WireType.LEN:
            field_desc.name = dec.read_string()
        elif field == 3 and wire == WireType.VARINT:
            field_desc.number = u64_to_i32(dec.read_varint())
        elif field == 4 and wire == WireType.VARINT:
            field_desc.label = Int(u64_to_i32(dec.read_varint()))
        elif field == 5 and wire == WireType.VARINT:
            field_desc.type = Int(u64_to_i32(dec.read_varint()))
        elif field == 6 and wire == WireType.LEN:
            field_desc.type_name = dec.read_string()
        elif field == 8 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            _merge_field_options(field_desc.packed, inner)
        elif field == 9 and wire == WireType.VARINT:
            field_desc.oneof_index = Int(u64_to_i32(dec.read_varint()))
        elif field == 17 and wire == WireType.VARINT:
            field_desc.proto3_optional = _read_bool(dec)
        else:
            dec.skip_field(wire)


def _merge_message[
    origin: ImmOrigin
](
    mut msg: MessageDesc,
    mut dec: WireReader[origin],
    mut out_msgs: List[MessageDesc],
) raises DecodeError:
    var pending_nested = List[List[Byte]]()
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 1 and wire == WireType.LEN:
            msg.name = dec.read_string()
        elif field == 2 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            var child = FieldDesc()
            _merge_field(child, inner)
            msg.fields.append(child^)
        elif field == 3 and wire == WireType.LEN:
            var span = dec.read_len_span()
            var copy = List[Byte](capacity=len(span))
            for i in range(len(span)):
                copy.append(span[i])
            pending_nested.append(copy^)
        elif field == 4 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            var enum = EnumDesc()
            _merge_enum(enum, inner)
            msg.enums.append(enum^)
        elif field == 7 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            _merge_message_options(msg.map_entry, inner)
        elif field == 8 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            var oneof = OneofDesc()
            _merge_oneof(oneof, inner)
            msg.oneofs.append(oneof^)
        else:
            dec.skip_field(wire)
    # Flatten nested types after this message has its name.
    var child_enclosing = msg.dotted_name()
    for i in range(len(pending_nested)):
        var inner = WireReader(pending_nested[i])
        var nested = MessageDesc()
        nested.enclosing = child_enclosing
        _merge_message(nested, inner, out_msgs)
        out_msgs.append(nested^)


def _merge_file[
    origin: ImmOrigin
](mut file: FileDesc, mut dec: WireReader[origin]) raises DecodeError:
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 1 and wire == WireType.LEN:
            file.name = dec.read_string()
        elif field == 2 and wire == WireType.LEN:
            file.package = dec.read_string()
        elif field == 3 and wire == WireType.LEN:
            file.dependency.append(dec.read_string())
        elif field == 4 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            var msg = MessageDesc()
            _merge_message(msg, inner, file.messages)
            file.messages.append(msg^)
        elif field == 5 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            var enum = EnumDesc()
            _merge_enum(enum, inner)
            file.enums.append(enum^)
        elif field == 10 and wire == WireType.VARINT:
            # proto2 unpacked repeated int32 (usual protoc output)
            file.public_dependency.append(u64_to_i32(dec.read_varint()))
        elif field == 10 and wire == WireType.LEN:
            var words = List[UInt64]()
            dec.read_packed_varint(words)
            for i in range(len(words)):
                file.public_dependency.append(u64_to_i32(words[i]))
        elif field == 12 and wire == WireType.LEN:
            file.syntax = dec.read_string()
        elif field == 14 and wire == WireType.VARINT:
            file.has_edition = True
            file.edition = u64_to_i32(dec.read_varint())
        else:
            dec.skip_field(wire)


def _index_messages(
    msgs: List[MessageDesc], prefix: String, mut names: List[String], mut flags: List[Bool]
):
    for i in range(len(msgs)):
        var full = prefix + "." + msgs[i].dotted_name()
        names.append(full)
        flags.append(msgs[i].map_entry)


def _lookup_map_entry(names: List[String], flags: List[Bool], type_name: String) -> Bool:
    for i in range(len(names)):
        if names[i] == type_name:
            return flags[i]
    return False


def _mark_maps_in_messages(
    mut msgs: List[MessageDesc], names: List[String], flags: List[Bool]
):
    for i in range(len(msgs)):
        for j in range(len(msgs[i].fields)):
            if (
                msgs[i].fields[j].type == TYPE_MESSAGE
                and msgs[i].fields[j].type_name.byte_length() != 0
            ):
                msgs[i].fields[j].is_map = _lookup_map_entry(
                    names, flags, msgs[i].fields[j].type_name
                )


def resolve_maps(mut set: FileDescSet):
    var names = List[String]()
    var flags = List[Bool]()
    for i in range(len(set.files)):
        var prefix = String()
        if set.files[i].package.byte_length() != 0:
            prefix = "." + set.files[i].package
        _index_messages(set.files[i].messages, prefix, names, flags)
    for i in range(len(set.files)):
        _mark_maps_in_messages(set.files[i].messages, names, flags)


def decode_file_descriptor_set[
    origin: ImmOrigin
](data: Span[Byte, origin]) raises DecodeError -> FileDescSet:
    var set = FileDescSet()
    var dec = WireReader[origin](data)
    while dec.remaining() > 0:
        var tag = dec.read_tag()
        var field = tag[0]
        var wire = tag[1]
        if field == 1 and wire == WireType.LEN:
            var inner = dec.subreader(dec.read_len_span())
            var file = FileDesc()
            _merge_file(file, inner)
            set.files.append(file^)
        else:
            dec.skip_field(wire)
    resolve_maps(set)
    return set^
