package serializers

import (
	"encoding/binary"
	"fmt"
	"math"

	flatbuffers "github.com/google/flatbuffers/go"
)

// IPC stream framing: uint32 continuation 0xFFFFFFFF, uint32 metadata size
// (flatbuffer plus padding), metadata, then body of Message.bodyLength.
// RecordBatch header type is 3. Field 0 (float64) is buffer 1; buffer 0 is
// the validity bitmap slot, length 0 when there are no nulls.
const (
	ipcContinuation      = 0xFFFFFFFF
	ipcHeaderRecordBatch = 3
	ipcSlotHeaderType    = 6
	ipcSlotHeader        = 8
	ipcSlotBodyLength    = 10
	ipcSlotRBLength      = 4
	ipcSlotRBBuffers     = 8
	ipcFloatBufferIndex  = 1
)

func projectIPCFloat0(data []byte) ([]float64, error) {
	var out []float64
	i := 0
	sawBatch := false
	for i < len(data) {
		if len(data)-i < 8 {
			return nil, fmt.Errorf("arrow-ipc: truncated framing at %d", i)
		}
		cid := binary.LittleEndian.Uint32(data[i : i+4])
		var metaStart, msgLen int
		switch cid {
		case 0:
			return finishIPCProject(out, sawBatch)
		case ipcContinuation:
			msgLen = int(binary.LittleEndian.Uint32(data[i+4 : i+8]))
			metaStart = i + 8
			if msgLen == 0 {
				return finishIPCProject(out, sawBatch)
			}
		default:
			msgLen = int(cid)
			metaStart = i + 4
		}
		if msgLen < 4 || metaStart < 0 || metaStart+msgLen > len(data) {
			return nil, fmt.Errorf("arrow-ipc: metadata length %d at %d", msgLen, i)
		}
		meta := data[metaStart : metaStart+msgLen]
		bodyLen, isBatch, bufOff, bufLen, nRows, err := ipcFloatBuffer(meta)
		if err != nil {
			return nil, err
		}
		bodyStart := metaStart + msgLen
		if bodyLen < 0 || bodyStart+int(bodyLen) > len(data) {
			return nil, fmt.Errorf("arrow-ipc: body length %d at %d", bodyLen, bodyStart)
		}
		if isBatch {
			sawBatch = true
			body := data[bodyStart : bodyStart+int(bodyLen)]
			part, err := decodeIPCFloats(body, bufOff, bufLen, nRows)
			if err != nil {
				return nil, err
			}
			out = append(out, part...)
		}
		i = bodyStart + int(bodyLen)
	}
	return finishIPCProject(out, sawBatch)
}

func finishIPCProject(out []float64, sawBatch bool) ([]float64, error) {
	if !sawBatch {
		return nil, fmt.Errorf("arrow-ipc: no record batch")
	}
	if out == nil {
		out = []float64{}
	}
	return out, nil
}

func ipcFloatBuffer(meta []byte) (bodyLen int64, isBatch bool, bufOff, bufLen, nRows int64, err error) {
	if len(meta) < 4 {
		return 0, false, 0, 0, 0, fmt.Errorf("arrow-ipc: short metadata")
	}
	root := flatbuffers.GetUOffsetT(meta)
	if int(root) < 0 || int(root) > len(meta) {
		return 0, false, 0, 0, 0, fmt.Errorf("arrow-ipc: bad flatbuffer root")
	}
	tab := flatbuffers.Table{Bytes: meta, Pos: root}
	hdrType := byte(0)
	if o := flatbuffers.UOffsetT(tab.Offset(ipcSlotHeaderType)); o != 0 {
		hdrType = tab.GetByte(o + tab.Pos)
	}
	if o := flatbuffers.UOffsetT(tab.Offset(ipcSlotBodyLength)); o != 0 {
		bodyLen = tab.GetInt64(o + tab.Pos)
	}
	if hdrType != ipcHeaderRecordBatch {
		return bodyLen, false, 0, 0, 0, nil
	}
	ho := flatbuffers.UOffsetT(tab.Offset(ipcSlotHeader))
	if ho == 0 {
		return 0, false, 0, 0, 0, fmt.Errorf("arrow-ipc: record batch missing header")
	}
	var hdr flatbuffers.Table
	tab.Union(&hdr, ho)
	if o := flatbuffers.UOffsetT(hdr.Offset(ipcSlotRBLength)); o != 0 {
		nRows = hdr.GetInt64(o + hdr.Pos)
	}
	bo := flatbuffers.UOffsetT(hdr.Offset(ipcSlotRBBuffers))
	if bo == 0 {
		return 0, false, 0, 0, 0, fmt.Errorf("arrow-ipc: record batch has no buffers")
	}
	nbuf := hdr.VectorLen(bo)
	if nbuf <= ipcFloatBufferIndex {
		return 0, false, 0, 0, 0, fmt.Errorf("arrow-ipc: f_float_0 needs buffer %d, have %d", ipcFloatBufferIndex, nbuf)
	}
	x := hdr.Vector(bo) + flatbuffers.UOffsetT(ipcFloatBufferIndex*16)
	bufOff = hdr.GetInt64(x)
	bufLen = hdr.GetInt64(x + 8)
	return bodyLen, true, bufOff, bufLen, nRows, nil
}

func decodeIPCFloats(body []byte, off, length, nRows int64) ([]float64, error) {
	if nRows < 0 || off < 0 || length < 0 {
		return nil, fmt.Errorf("arrow-ipc: bad float buffer off=%d len=%d rows=%d", off, length, nRows)
	}
	need := nRows * 8
	if length != need {
		return nil, fmt.Errorf("arrow-ipc: f_float_0 buffer length %d want %d", length, need)
	}
	if off+length > int64(len(body)) {
		return nil, fmt.Errorf("arrow-ipc: f_float_0 buffer past body")
	}
	raw := body[off : off+length]
	out := make([]float64, nRows)
	for i := int64(0); i < nRows; i++ {
		bits := binary.LittleEndian.Uint64(raw[i*8 : i*8+8])
		out[i] = math.Float64frombits(bits)
	}
	return out, nil
}
