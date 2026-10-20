package model

import (
	"math"

	modelv2 "serializer-benchmark-go/model/v2"
)

// tensorFidelity is bit-exact for float32, including negative zero and NaN payload.
// reflect.DeepEqual treats NaN as unequal and negative zero as equal to +0.
func tensorFidelity(expected, actual any) (equal bool, matched bool) {
	switch e := expected.(type) {
	case modelv2.Tensor:
		a, ok := actual.(modelv2.Tensor)
		if !ok {
			return false, true
		}
		return tensorsEqual(e, a), true
	case modelv2.Prompt:
		a, ok := actual.(modelv2.Prompt)
		if !ok {
			return false, true
		}
		return promptsEqual(e, a), true
	case modelv2.Shard:
		a, ok := actual.(modelv2.Shard)
		if !ok {
			return false, true
		}
		return shardsEqual(e, a), true
	case modelv2.Request:
		a, ok := actual.(modelv2.Request)
		if !ok {
			return false, true
		}
		return requestsEqual(e, a), true
	default:
		return false, false
	}
}

func tensorsEqual(a, b modelv2.Tensor) bool {
	return a.Rows == b.Rows && a.Cols == b.Cols && f32sEqual(a.Values, b.Values)
}

func promptsEqual(a, b modelv2.Prompt) bool {
	return a.Batch == b.Batch && a.Seq == b.Seq &&
		i64sEqual(a.InputIDs, b.InputIDs) &&
		i64sEqual(a.AttentionMask, b.AttentionMask) &&
		i64sEqual(a.PositionIDs, b.PositionIDs)
}

func shardsEqual(a, b modelv2.Shard) bool {
	return a.Vocab == b.Vocab && a.Hidden == b.Hidden && a.FFN == b.FFN &&
		f32sEqual(a.TokEmb, b.TokEmb) &&
		f32sEqual(a.Attn, b.Attn) &&
		f32sEqual(a.FFNWeight, b.FFNWeight) &&
		f32sEqual(a.Norm, b.Norm)
}

func requestsEqual(a, b modelv2.Request) bool {
	return a.RequestID == b.RequestID && a.Model == b.Model &&
		math.Float32bits(a.Temperature) == math.Float32bits(b.Temperature) &&
		promptsEqual(a.Inputs, b.Inputs)
}

func f32sEqual(a, b []float32) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if math.Float32bits(a[i]) != math.Float32bits(b[i]) {
			return false
		}
	}
	return true
}

func i64sEqual(a, b []int64) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
