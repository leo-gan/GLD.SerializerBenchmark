//! Repeating group dimensions

use crate::*;

pub use encoder::GroupSizeEncodingEncoder;
pub use decoder::GroupSizeEncodingDecoder;

pub const ENCODED_LENGTH: usize = 4;

pub mod encoder {
    use super::*;

    #[derive(Debug, Default)]
    pub struct GroupSizeEncodingEncoder<P> {
        parent: Option<P>,
        offset: usize,
    }

    impl<'a, P> Writer<'a> for GroupSizeEncodingEncoder<P> where P: Writer<'a> + Default {
        #[inline]
        fn get_buf_mut(&mut self) -> &mut WriteBuf<'a> {
            if let Some(parent) = self.parent.as_mut() {
                parent.get_buf_mut()
            } else {
                panic!("parent was None")
            }
        }
    }

    impl<'a, P> GroupSizeEncodingEncoder<P> where P: Writer<'a> + Default {
        pub fn wrap(mut self, parent: P, offset: usize) -> Self {
            self.parent = Some(parent);
            self.offset = offset;
            self
        }

        /// parent fns
        #[inline]
        pub fn parent(&mut self) -> SbeResult<P> {
            self.parent.take().ok_or(SbeErr::ParentNotSet)
        }

        /// primitive field 'blockLength'
        /// - min value: 0
        /// - max value: 65534
        /// - null value: 0xffff_u16
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 0
        /// - encodedLength: 2
        /// - version: 0
        #[inline]
        pub fn block_length(&mut self, value: u16) -> &mut Self {
            let offset = self.offset;
            self.get_buf_mut().put_u16_at(offset, value);
            self
        }

        /// primitive field 'numInGroup'
        /// - min value: 0
        /// - max value: 65534
        /// - null value: 0xffff_u16
        /// - characterEncoding: null
        /// - semanticType: null
        /// - encodedOffset: 2
        /// - encodedLength: 2
        /// - version: 0
        #[inline]
        pub fn num_in_group(&mut self, value: u16) -> &mut Self {
            let offset = self.offset + 2;
            self.get_buf_mut().put_u16_at(offset, value);
            self
        }

        /// Set all optional fields to their null values.
        #[inline]
        pub fn nullify_optional_fields(&mut self) -> &mut Self {
            self
        }

    }
} // end encoder mod 

pub mod decoder {
    use super::*;

    #[derive(Debug, Default)]
    pub struct GroupSizeEncodingDecoder<P> {
        parent: Option<P>,
        offset: usize,
    }

    impl<'a, P> ActingVersion for GroupSizeEncodingDecoder<P> where P: Reader<'a> + ActingVersion + Default {
        #[inline]
        fn acting_version(&self) -> u16 {
            self.parent.as_ref().unwrap().acting_version()
        }
    }

    impl<'a, P> Reader<'a> for GroupSizeEncodingDecoder<P> where P: Reader<'a> + Default {
        #[inline]
        fn get_buf(&self) -> &ReadBuf<'a> {
            self.parent.as_ref().expect("parent missing").get_buf()
        }
    }

    impl<'a, P> GroupSizeEncodingDecoder<P> where P: Reader<'a> + Default {
        pub fn wrap(mut self, parent: P, offset: usize) -> Self {
            self.parent = Some(parent);
            self.offset = offset;
            self
        }

        #[inline]
        pub fn parent(&mut self) -> SbeResult<P> {
            self.parent.take().ok_or(SbeErr::ParentNotSet)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn block_length(&self) -> u16 {
            self.get_buf().get_u16_at(self.offset)
        }

        /// primitive field - 'REQUIRED'
        #[inline]
        pub fn num_in_group(&self) -> u16 {
            self.get_buf().get_u16_at(self.offset + 2)
        }

    }
} // end decoder mod 
