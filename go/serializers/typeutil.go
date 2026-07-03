package serializers

import "reflect"

func typeOf(v any) reflect.Type {
	return reflect.TypeOf(v)
}
