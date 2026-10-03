use crate::*;

pub use decoder::TableDecoder;
pub use encoder::TableEncoder;

pub use crate::SBE_SCHEMA_ID;
pub use crate::SBE_SCHEMA_VERSION;
pub use crate::SBE_SEMANTIC_VERSION;

pub const SBE_BLOCK_LENGTH: u16 = 160;
pub const SBE_TEMPLATE_ID: u16 = 2;

pub mod encoder {
    use super::*;
    use message_header_codec::*;

    #[derive(Debug, Default)]
    pub struct TableEncoder<'a> {
        buf: WriteBuf<'a>,
        initial_offset: usize,
        offset: usize,
        limit: usize,
    }

    impl<'a> Writer<'a> for TableEncoder<'a> {
        #[inline]
        fn get_buf_mut(&mut self) -> &mut WriteBuf<'a> {
            &mut self.buf
        }
    }

    impl<'a> Encoder<'a> for TableEncoder<'a> {
        #[inline]
        fn get_limit(&self) -> usize {
            self.limit
        }

        #[inline]
        fn set_limit(&mut self, limit: usize) {
            self.limit = limit;
        }
    }

    impl<'a> TableEncoder<'a> {
        pub fn wrap(mut self, buf: WriteBuf<'a>, offset: usize) -> Self {
            let limit = offset + SBE_BLOCK_LENGTH as usize;
            self.buf = buf;
            self.initial_offset = offset;
            self.offset = offset;
            self.limit = limit;
            self
        }

        #[inline]
        pub const fn encoded_length(&self) -> usize {
            self.limit - self.offset
        }

        #[inline]
        pub fn header(self, offset: usize) -> MessageHeaderEncoder<Self> {
            let mut header = MessageHeaderEncoder::default().wrap(self, offset);
            header.block_length(SBE_BLOCK_LENGTH);
            header.template_id(SBE_TEMPLATE_ID);
            header.schema_id(SBE_SCHEMA_ID);
            header.version(SBE_SCHEMA_VERSION);
            header
        }

        /// primitive field 'f_float_0'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 0
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_0(&mut self, value: f64) -> &mut Self {
            let offset = self.offset;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_1'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 8
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_1(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 8;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_2'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 16
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_2(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 16;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_3'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 24
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_3(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 24;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_4'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 32
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_4(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 32;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_5'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 40
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_5(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 40;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_6'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 48
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_6(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 48;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_7'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 56
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_7(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 56;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_8'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 64
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_8(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 64;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_9'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 72
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_9(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 72;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_10'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 80
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_10(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 80;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_11'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 88
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_11(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 88;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_12'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 96
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_12(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 96;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_13'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 104
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_13(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 104;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_14'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 112
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_14(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 112;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_float_15'
        /// - min value: -1.7976931348623157E308
        /// - max value: 1.7976931348623157E308
        /// - null value: f64::NAN
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 120
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_float_15(&mut self, value: f64) -> &mut Self {
            let offset = self.offset + 120;
            self.get_buf_mut().put_f64_at(offset, value);
            self
        }

        /// primitive field 'f_int_0'
        /// - min value: -9223372036854775807
        /// - max value: 9223372036854775807
        /// - null value: -9223372036854775808_i64
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 128
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_int_0(&mut self, value: i64) -> &mut Self {
            let offset = self.offset + 128;
            self.get_buf_mut().put_i64_at(offset, value);
            self
        }

        /// primitive field 'f_int_1'
        /// - min value: -9223372036854775807
        /// - max value: 9223372036854775807
        /// - null value: -9223372036854775808_i64
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 136
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_int_1(&mut self, value: i64) -> &mut Self {
            let offset = self.offset + 136;
            self.get_buf_mut().put_i64_at(offset, value);
            self
        }

        /// primitive field 'f_int_2'
        /// - min value: -9223372036854775807
        /// - max value: 9223372036854775807
        /// - null value: -9223372036854775808_i64
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 144
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_int_2(&mut self, value: i64) -> &mut Self {
            let offset = self.offset + 144;
            self.get_buf_mut().put_i64_at(offset, value);
            self
        }

        /// primitive field 'f_int_3'
        /// - min value: -9223372036854775807
        /// - max value: 9223372036854775807
        /// - null value: -9223372036854775808_i64
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 152
        /// - encodedLength: 8
        /// - version: 0
        #[inline]
        pub fn f_int_3(&mut self, value: i64) -> &mut Self {
            let offset = self.offset + 152;
            self.get_buf_mut().put_i64_at(offset, value);
            self
        }

        /// VAR_DATA ENCODER - character encoding: 'UTF-8'
        #[inline]
        pub fn f_str_0(&mut self, value: &str) -> &mut Self {
            let limit = self.get_limit();
            let data_length = value.len().min((u32::MAX - 1) as usize);
            self.set_limit(limit + 4 + data_length);
            self.get_buf_mut().put_u32_at(limit, data_length as u32);
            self.get_buf_mut().put_slice_at(limit + 4, &value[0..data_length].as_bytes());
            self
        }

        /// VAR_DATA ENCODER - character encoding: 'UTF-8'
        #[inline]
        pub fn f_str_1(&mut self, value: &str) -> &mut Self {
            let limit = self.get_limit();
            let data_length = value.len().min((u32::MAX - 1) as usize);
            self.set_limit(limit + 4 + data_length);
            self.get_buf_mut().put_u32_at(limit, data_length as u32);
            self.get_buf_mut().put_slice_at(limit + 4, &value[0..data_length].as_bytes());
            self
        }

    }

} // end encoder

pub mod decoder {
    use super::*;
    use message_header_codec::*;

    #[derive(Clone, Copy, Debug, Default)]
    pub struct TableDecoder<'a> {
        buf: ReadBuf<'a>,
        initial_offset: usize,
        offset: usize,
        limit: usize,
        pub acting_block_length: u16,
        pub acting_version: u16,
    }

    impl ActingVersion for TableDecoder<'_> {
        #[inline]
        fn acting_version(&self) -> u16 {
            self.acting_version
        }
    }

    impl<'a> Reader<'a> for TableDecoder<'a> {
        #[inline]
        fn get_buf(&self) -> &ReadBuf<'a> {
            &self.buf
        }
    }

    impl<'a> Decoder<'a> for TableDecoder<'a> {
        #[inline]
        fn get_limit(&self) -> usize {
            self.limit
        }

        #[inline]
        fn set_limit(&mut self, limit: usize) {
            self.limit = limit;
        }
    }

    impl<'a> TableDecoder<'a> {
        pub fn wrap(
            mut self,
            buf: ReadBuf<'a>,
            offset: usize,
            acting_block_length: u16,
            acting_version: u16,
        ) -> Self {
            let limit = offset + acting_block_length as usize;
            self.buf = buf;
            self.initial_offset = offset;
            self.offset = offset;
            self.limit = limit;
            self.acting_block_length = acting_block_length;
            self.acting_version = acting_version;
            self
        }

        #[inline]
        pub const fn encoded_length(&self) -> usize {
            self.limit - self.offset
        }

        #[inline]
        pub fn header(self, mut header: MessageHeaderDecoder<ReadBuf<'a>>, offset: usize) -> Self {
            debug_assert_eq!(SBE_TEMPLATE_ID, header.template_id());
            let acting_block_length = header.block_length();
            let acting_version = header.version();

            self.wrap(
                header.parent().unwrap(),
                offset + message_header_codec::ENCODED_LENGTH,
                acting_block_length,
                acting_version,
            )
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_0(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_1(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 8)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_2(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 16)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_3(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 24)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_4(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 32)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_5(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 40)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_6(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 48)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_7(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 56)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_8(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 64)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_9(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 72)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_10(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 80)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_11(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 88)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_12(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 96)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_13(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 104)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_14(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 112)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_float_15(&self) -> f64 {
            self.get_buf().get_f64_at(self.offset + 120)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_int_0(&self) -> i64 {
            self.get_buf().get_i64_at(self.offset + 128)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_int_1(&self) -> i64 {
            self.get_buf().get_i64_at(self.offset + 136)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_int_2(&self) -> i64 {
            self.get_buf().get_i64_at(self.offset + 144)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn f_int_3(&self) -> i64 {
            self.get_buf().get_i64_at(self.offset + 152)
        }

        /// VAR_DATA DECODER - character encoding: 'UTF-8'
        #[inline]
        pub fn f_str_0_decoder(&mut self) -> (usize, usize) {
            let offset = self.get_limit();
            let data_length = self.get_buf().get_u32_at(offset) as usize;
            self.set_limit(offset + 4 + data_length);
            (offset + 4, data_length)
        }

        #[inline]
        pub fn f_str_0_slice(&'a self, coordinates: (usize, usize)) -> &'a [u8] {
            debug_assert!(self.get_limit() >= coordinates.0 + coordinates.1);
            self.get_buf().get_slice_at(coordinates.0, coordinates.1)
        }

        /// VAR_DATA DECODER - character encoding: 'UTF-8'
        #[inline]
        pub fn f_str_1_decoder(&mut self) -> (usize, usize) {
            let offset = self.get_limit();
            let data_length = self.get_buf().get_u32_at(offset) as usize;
            self.set_limit(offset + 4 + data_length);
            (offset + 4, data_length)
        }

        #[inline]
        pub fn f_str_1_slice(&'a self, coordinates: (usize, usize)) -> &'a [u8] {
            debug_assert!(self.get_limit() >= coordinates.0 + coordinates.1);
            self.get_buf().get_slice_at(coordinates.0, coordinates.1)
        }

    }

} // end decoder

