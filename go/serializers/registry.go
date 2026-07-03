package serializers

// All returns registered serializers in a stable display order.
func All() []BenchSerializer {
	return []BenchSerializer{
		// JSON family
		newEncodingJSON(),
		newSonicJSON(),
		newGoccyJSON(),
		newJSONIter(),
		newSegmentioJSON(),
		// Binary schemaless
		newVmihailencoMsgpack(),
		newShamatonMsgpack(),
		newFxamackerCBOR(),
		newEncodingGob(),
		newMongoBSON(),
		// Schema / IDL
		newGoogleProtobuf(),
		newHambaAvro(),
	}
}
