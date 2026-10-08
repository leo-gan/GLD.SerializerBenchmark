package serializers

import (
	"fmt"
	"io"

	sbe "serializer-benchmark-go/gen/sbe"
	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

// sbeCodec fills sbe-tool 1.40.2 Go flyweights inside SerializeBytes.
// The message header is applied there too. nested_table is not an SBE body.
// table_project reads F_float_0 and skips the variable strings.
type sbeCodec struct {
	fxName string
}

func newSBE() *sbeCodec { return &sbeCodec{} }

func (s *sbeCodec) Name() string           { return "sbe" }
func (s *sbeCodec) Version() string        { return "1.40.2" }
func (s *sbeCodec) StreamMode() StreamMode { return StreamAdapted }
func (s *sbeCodec) NativeKind() NativeKind { return NativeMessage }

func (s *sbeCodec) Supports(n string) bool {
	switch n {
	case "table", "table_project", "signal":
		return true
	default:
		return false
	}
}

func (s *sbeCodec) Prepare(fx model.Fixture) error {
	switch fx.Name {
	case "table", "table_project", "signal":
		s.fxName = fx.Name
		return nil
	default:
		return fmt.Errorf("sbe: unsupported type %s", fx.Name)
	}
}

func (s *sbeCodec) SerializeBytes(fx model.Fixture) ([]byte, error) {
	switch s.fxName {
	case "table", "table_project":
		rows, err := asTableRows(fx.Value)
		if err != nil {
			return nil, err
		}
		return encodeSBETables(rows)
	case "signal":
		rows, err := asSignalRows(fx.Value)
		if err != nil {
			return nil, err
		}
		return encodeSBESignals(rows)
	default:
		return nil, fmt.Errorf("sbe: unsupported type %s", s.fxName)
	}
}

func (s *sbeCodec) DeserializeBytes(buf []byte) (any, error) {
	switch s.fxName {
	case "table", "table_project":
		return decodeSBETables(buf, s.fxName == "table_project")
	case "signal":
		return decodeSBESignals(buf)
	default:
		return nil, fmt.Errorf("sbe: prepare() required")
	}
}

func (s *sbeCodec) SerializeStream(fx model.Fixture, w io.Writer) (int, error) {
	return AdaptedSerializeStream(s, fx, w)
}

func (s *sbeCodec) DeserializeStream(r io.Reader) (any, error) {
	return AdaptedDeserializeStream(s, r)
}

func tableMsgLen(row modelv2.TableRow) int {
	return int(sbe.MessageHeaderEncodedLength) + int(sbe.TableSbeBlockLength) + 4 + len(row.FStr0) + 4 + len(row.FStr1)
}

func signalMsgLen(row modelv2.Signal) int {
	return int(sbe.MessageHeaderEncodedLength) + int(sbe.SignalSbeBlockLength) + 4 + 16*len(row.Legs) + 4 + len(row.Symbol) + 4 + len(row.Venue)
}

func encodeSBETables(rows []modelv2.TableRow) ([]byte, error) {
	n := 0
	for _, row := range rows {
		n += tableMsgLen(row)
	}
	buf := make([]byte, n)
	off := uint64(0)
	for _, row := range rows {
		next, err := writeSBETable(buf, off, row)
		if err != nil {
			return nil, err
		}
		off = next
	}
	if int(off) != len(buf) {
		return nil, fmt.Errorf("sbe: table encoded %d want %d", off, len(buf))
	}
	return buf, nil
}

func writeSBETable(buf []byte, off uint64, row modelv2.TableRow) (uint64, error) {
	var m sbe.Table
	m.WrapAndApplyHeader(buf, off, uint64(len(buf)))
	m.SetF_float_0(row.FFloat0)
	m.SetF_float_1(row.FFloat1)
	m.SetF_float_2(row.FFloat2)
	m.SetF_float_3(row.FFloat3)
	m.SetF_float_4(row.FFloat4)
	m.SetF_float_5(row.FFloat5)
	m.SetF_float_6(row.FFloat6)
	m.SetF_float_7(row.FFloat7)
	m.SetF_float_8(row.FFloat8)
	m.SetF_float_9(row.FFloat9)
	m.SetF_float_10(row.FFloat10)
	m.SetF_float_11(row.FFloat11)
	m.SetF_float_12(row.FFloat12)
	m.SetF_float_13(row.FFloat13)
	m.SetF_float_14(row.FFloat14)
	m.SetF_float_15(row.FFloat15)
	m.SetF_int_0(row.FInt0)
	m.SetF_int_1(row.FInt1)
	m.SetF_int_2(row.FInt2)
	m.SetF_int_3(row.FInt3)
	m.PutF_str_0(row.FStr0)
	m.PutF_str_1(row.FStr1)
	next := off + sbe.MessageHeaderEncodedLength + m.EncodedLength()
	if int(next-off) != tableMsgLen(row) {
		return 0, fmt.Errorf("sbe: table message %d want %d", next-off, tableMsgLen(row))
	}
	return next, nil
}

func readSBETable(m *sbe.Table) modelv2.TableRow {
	row := modelv2.TableRow{
		FFloat0: m.F_float_0(), FFloat1: m.F_float_1(), FFloat2: m.F_float_2(), FFloat3: m.F_float_3(),
		FFloat4: m.F_float_4(), FFloat5: m.F_float_5(), FFloat6: m.F_float_6(), FFloat7: m.F_float_7(),
		FFloat8: m.F_float_8(), FFloat9: m.F_float_9(), FFloat10: m.F_float_10(), FFloat11: m.F_float_11(),
		FFloat12: m.F_float_12(), FFloat13: m.F_float_13(), FFloat14: m.F_float_14(), FFloat15: m.F_float_15(),
		FInt0: m.F_int_0(), FInt1: m.F_int_1(), FInt2: m.F_int_2(), FInt3: m.F_int_3(),
	}
	row.FStr0 = m.F_str_0()
	row.FStr1 = m.F_str_1()
	return row
}

func decodeSBETables(buf []byte, project bool) (any, error) {
	var rows []modelv2.TableRow
	var floats []float64
	off := uint64(0)
	blen := uint64(len(buf))
	for off < blen {
		var hdr sbe.MessageHeader
		hdr.Wrap(buf, off, 0, blen)
		if hdr.TemplateId() != sbe.TableSbeTemplateID {
			return nil, fmt.Errorf("sbe: template %d want table", hdr.TemplateId())
		}
		var m sbe.Table
		m.WrapForDecode(buf, off+sbe.MessageHeaderEncodedLength, uint64(hdr.BlockLength()), uint64(hdr.Version()), blen)
		if project {
			floats = append(floats, m.F_float_0())
			m.Skip()
		} else {
			rows = append(rows, readSBETable(&m))
		}
		next := off + sbe.MessageHeaderEncodedLength + m.EncodedLength()
		if next <= off || next > blen {
			return nil, fmt.Errorf("sbe: table cursor %d -> %d", off, next)
		}
		off = next
	}
	if project {
		if floats == nil {
			floats = []float64{}
		}
		return floats, nil
	}
	if len(rows) == 1 {
		return rows[0], nil
	}
	return rows, nil
}

func encodeSBESignals(rows []modelv2.Signal) ([]byte, error) {
	n := 0
	for _, row := range rows {
		n += signalMsgLen(row)
	}
	buf := make([]byte, n)
	off := uint64(0)
	for _, row := range rows {
		next, err := writeSBESignal(buf, off, row)
		if err != nil {
			return nil, err
		}
		off = next
	}
	if int(off) != len(buf) {
		return nil, fmt.Errorf("sbe: signal encoded %d want %d", off, len(buf))
	}
	return buf, nil
}

func writeSBESignal(buf []byte, off uint64, row modelv2.Signal) (uint64, error) {
	var m sbe.Signal
	m.WrapAndApplyHeader(buf, off, uint64(len(buf)))
	m.SetSeq(row.Seq)
	m.SetTs(row.TS)
	m.SetPrice_mantissa(row.PriceMantissa)
	m.SetQty(row.Qty)
	m.SetFlags(row.Flags)
	legs := m.LegsCount(uint16(len(row.Legs)))
	for _, leg := range row.Legs {
		legs.Next().SetLeg_id(leg.LegID).SetLeg_qty(leg.LegQty).SetLeg_pad(leg.LegPad)
	}
	m.PutSymbol(row.Symbol)
	m.PutVenue(row.Venue)
	next := off + sbe.MessageHeaderEncodedLength + m.EncodedLength()
	if int(next-off) != signalMsgLen(row) {
		return 0, fmt.Errorf("sbe: signal message %d want %d", next-off, signalMsgLen(row))
	}
	return next, nil
}

func decodeSBESignals(buf []byte) (any, error) {
	var rows []modelv2.Signal
	off := uint64(0)
	blen := uint64(len(buf))
	for off < blen {
		var hdr sbe.MessageHeader
		hdr.Wrap(buf, off, 0, blen)
		if hdr.TemplateId() != sbe.SignalSbeTemplateID {
			return nil, fmt.Errorf("sbe: template %d want signal", hdr.TemplateId())
		}
		var m sbe.Signal
		m.WrapForDecode(buf, off+sbe.MessageHeaderEncodedLength, uint64(hdr.BlockLength()), uint64(hdr.Version()), blen)
		sig := modelv2.Signal{
			Seq: m.Seq(), TS: m.Ts(), PriceMantissa: m.Price_mantissa(),
			Qty: m.Qty(), Flags: m.Flags(),
		}
		g := m.Legs()
		sig.Legs = make([]modelv2.SignalLeg, 0, g.Count())
		for g.HasNext() {
			g.Next()
			sig.Legs = append(sig.Legs, modelv2.SignalLeg{
				LegID: g.Leg_id(), LegQty: g.Leg_qty(), LegPad: g.Leg_pad(),
			})
		}
		sig.Symbol = m.Symbol()
		sig.Venue = m.Venue()
		rows = append(rows, sig)
		next := off + sbe.MessageHeaderEncodedLength + m.EncodedLength()
		if next <= off || next > blen {
			return nil, fmt.Errorf("sbe: signal cursor %d -> %d", off, next)
		}
		off = next
	}
	if len(rows) == 1 {
		return rows[0], nil
	}
	return rows, nil
}
