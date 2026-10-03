/* Generated SBE (Simple Binary Encoding) message codec */
#ifndef _BENCHMARK_V2_TABLE_CXX_H_
#define _BENCHMARK_V2_TABLE_CXX_H_

#if __cplusplus >= 201103L
#  define SBE_CONSTEXPR constexpr
#  define SBE_NOEXCEPT noexcept
#else
#  define SBE_CONSTEXPR
#  define SBE_NOEXCEPT
#endif

#if __cplusplus >= 201703L
#  include <string_view>
#  define SBE_NODISCARD [[nodiscard]]
#  if !defined(SBE_USE_STRING_VIEW)
#    define SBE_USE_STRING_VIEW 1
#  endif
#else
#  define SBE_NODISCARD
#endif

#if __cplusplus >= 202002L
#  include <span>
#  if !defined(SBE_USE_SPAN)
#    define SBE_USE_SPAN 1
#  endif
#endif

#if !defined(__STDC_LIMIT_MACROS)
#  define __STDC_LIMIT_MACROS 1
#endif

#include <cstdint>
#include <limits>
#include <cstring>
#include <iomanip>
#include <ostream>
#include <stdexcept>
#include <sstream>
#include <string>
#include <vector>
#include <tuple>

#if defined(WIN32) || defined(_WIN32)
#  define SBE_BIG_ENDIAN_ENCODE_16(v) _byteswap_ushort(v)
#  define SBE_BIG_ENDIAN_ENCODE_32(v) _byteswap_ulong(v)
#  define SBE_BIG_ENDIAN_ENCODE_64(v) _byteswap_uint64(v)
#  define SBE_LITTLE_ENDIAN_ENCODE_16(v) (v)
#  define SBE_LITTLE_ENDIAN_ENCODE_32(v) (v)
#  define SBE_LITTLE_ENDIAN_ENCODE_64(v) (v)
#elif __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#  define SBE_BIG_ENDIAN_ENCODE_16(v) __builtin_bswap16(v)
#  define SBE_BIG_ENDIAN_ENCODE_32(v) __builtin_bswap32(v)
#  define SBE_BIG_ENDIAN_ENCODE_64(v) __builtin_bswap64(v)
#  define SBE_LITTLE_ENDIAN_ENCODE_16(v) (v)
#  define SBE_LITTLE_ENDIAN_ENCODE_32(v) (v)
#  define SBE_LITTLE_ENDIAN_ENCODE_64(v) (v)
#elif __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#  define SBE_LITTLE_ENDIAN_ENCODE_16(v) __builtin_bswap16(v)
#  define SBE_LITTLE_ENDIAN_ENCODE_32(v) __builtin_bswap32(v)
#  define SBE_LITTLE_ENDIAN_ENCODE_64(v) __builtin_bswap64(v)
#  define SBE_BIG_ENDIAN_ENCODE_16(v) (v)
#  define SBE_BIG_ENDIAN_ENCODE_32(v) (v)
#  define SBE_BIG_ENDIAN_ENCODE_64(v) (v)
#else
#  error "Byte Ordering of platform not determined. Set __BYTE_ORDER__ manually before including this file."
#endif

#if !defined(SBE_BOUNDS_CHECK_EXPECT)
#  if defined(SBE_NO_BOUNDS_CHECK)
#    define SBE_BOUNDS_CHECK_EXPECT(exp, c) (false)
#  elif defined(_MSC_VER)
#    define SBE_BOUNDS_CHECK_EXPECT(exp, c) (exp)
#  else 
#    define SBE_BOUNDS_CHECK_EXPECT(exp, c) (__builtin_expect(exp, c))
#  endif

#endif

#define SBE_FLOAT_NAN std::numeric_limits<float>::quiet_NaN()
#define SBE_DOUBLE_NAN std::numeric_limits<double>::quiet_NaN()
#define SBE_FLOAT_INFINITY std::numeric_limits<float>::infinity()
#define SBE_DOUBLE_INFINITY std::numeric_limits<double>::infinity()
#define SBE_NULLVALUE_INT8 (std::numeric_limits<std::int8_t>::min)()
#define SBE_NULLVALUE_INT16 (std::numeric_limits<std::int16_t>::min)()
#define SBE_NULLVALUE_INT32 (std::numeric_limits<std::int32_t>::min)()
#define SBE_NULLVALUE_INT64 (std::numeric_limits<std::int64_t>::min)()
#define SBE_NULLVALUE_UINT8 (std::numeric_limits<std::uint8_t>::max)()
#define SBE_NULLVALUE_UINT16 (std::numeric_limits<std::uint16_t>::max)()
#define SBE_NULLVALUE_UINT32 (std::numeric_limits<std::uint32_t>::max)()
#define SBE_NULLVALUE_UINT64 (std::numeric_limits<std::uint64_t>::max)()


#include "MessageHeader.h"
#include "GroupSizeEncoding.h"
#include "VarStringEncoding.h"

namespace benchmark {
namespace v2 {

class Table
{
private:
    char *m_buffer = nullptr;
    std::uint64_t m_bufferLength = 0;
    std::uint64_t m_offset = 0;
    std::uint64_t m_position = 0;
    std::uint64_t m_actingBlockLength = 0;
    std::uint64_t m_actingVersion = 0;

    inline std::uint64_t *sbePositionPtr() SBE_NOEXCEPT
    {
        return &m_position;
    }

public:
    static constexpr std::uint16_t SBE_BLOCK_LENGTH = static_cast<std::uint16_t>(160);
    static constexpr std::uint16_t SBE_TEMPLATE_ID = static_cast<std::uint16_t>(2);
    static constexpr std::uint16_t SBE_SCHEMA_ID = static_cast<std::uint16_t>(1);
    static constexpr std::uint16_t SBE_SCHEMA_VERSION = static_cast<std::uint16_t>(0);
    static constexpr const char* SBE_SEMANTIC_VERSION = "1.0.0";

    enum MetaAttribute
    {
        EPOCH, TIME_UNIT, SEMANTIC_TYPE, PRESENCE
    };

    union sbe_float_as_uint_u
    {
        float fp_value;
        std::uint32_t uint_value;
    };

    union sbe_double_as_uint_u
    {
        double fp_value;
        std::uint64_t uint_value;
    };

    using messageHeader = MessageHeader;

    Table() = default;

    Table(
        char *buffer,
        const std::uint64_t offset,
        const std::uint64_t bufferLength,
        const std::uint64_t actingBlockLength,
        const std::uint64_t actingVersion) :
        m_buffer(buffer),
        m_bufferLength(bufferLength),
        m_offset(offset),
        m_position(sbeCheckPosition(offset + actingBlockLength)),
        m_actingBlockLength(actingBlockLength),
        m_actingVersion(actingVersion)
    {
    }

    Table(char *buffer, const std::uint64_t bufferLength) :
        Table(buffer, 0, bufferLength, sbeBlockLength(), sbeSchemaVersion())
    {
    }

    Table(
        char *buffer,
        const std::uint64_t bufferLength,
        const std::uint64_t actingBlockLength,
        const std::uint64_t actingVersion) :
        Table(buffer, 0, bufferLength, actingBlockLength, actingVersion)
    {
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint16_t sbeBlockLength() SBE_NOEXCEPT
    {
        return static_cast<std::uint16_t>(160);
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t sbeBlockAndHeaderLength() SBE_NOEXCEPT
    {
        return messageHeader::encodedLength() + sbeBlockLength();
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint16_t sbeTemplateId() SBE_NOEXCEPT
    {
        return static_cast<std::uint16_t>(2);
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint16_t sbeSchemaId() SBE_NOEXCEPT
    {
        return static_cast<std::uint16_t>(1);
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint16_t sbeSchemaVersion() SBE_NOEXCEPT
    {
        return static_cast<std::uint16_t>(0);
    }

    SBE_NODISCARD static const char *sbeSemanticVersion() SBE_NOEXCEPT
    {
        return "1.0.0";
    }

    SBE_NODISCARD static SBE_CONSTEXPR const char *sbeSemanticType() SBE_NOEXCEPT
    {
        return "";
    }

    SBE_NODISCARD std::uint64_t offset() const SBE_NOEXCEPT
    {
        return m_offset;
    }

    Table &wrapForEncode(char *buffer, const std::uint64_t offset, const std::uint64_t bufferLength)
    {
        m_buffer = buffer;
        m_bufferLength = bufferLength;
        m_offset = offset;
        m_actingBlockLength = sbeBlockLength();
        m_actingVersion = sbeSchemaVersion();
        m_position = sbeCheckPosition(m_offset + m_actingBlockLength);
        return *this;
    }

    Table &wrapAndApplyHeader(char *buffer, const std::uint64_t offset, const std::uint64_t bufferLength)
    {
        messageHeader hdr(buffer, offset, bufferLength, sbeSchemaVersion());

        hdr
            .blockLength(sbeBlockLength())
            .templateId(sbeTemplateId())
            .schemaId(sbeSchemaId())
            .version(sbeSchemaVersion());

        m_buffer = buffer;
        m_bufferLength = bufferLength;
        m_offset = offset + messageHeader::encodedLength();
        m_actingBlockLength = sbeBlockLength();
        m_actingVersion = sbeSchemaVersion();
        m_position = sbeCheckPosition(m_offset + m_actingBlockLength);
        return *this;
    }

    Table &wrapForDecode(
        char *buffer,
        const std::uint64_t offset,
        const std::uint64_t actingBlockLength,
        const std::uint64_t actingVersion,
        const std::uint64_t bufferLength)
    {
        m_buffer = buffer;
        m_bufferLength = bufferLength;
        m_offset = offset;
        m_actingBlockLength = actingBlockLength;
        m_actingVersion = actingVersion;
        m_position = sbeCheckPosition(m_offset + m_actingBlockLength);
        return *this;
    }

    Table &sbeRewind()
    {
        return wrapForDecode(m_buffer, m_offset, m_actingBlockLength, m_actingVersion, m_bufferLength);
    }

    SBE_NODISCARD std::uint64_t sbePosition() const SBE_NOEXCEPT
    {
        return m_position;
    }

    // NOLINTNEXTLINE(readability-convert-member-functions-to-static)
    std::uint64_t sbeCheckPosition(const std::uint64_t position)
    {
        if (SBE_BOUNDS_CHECK_EXPECT((position > m_bufferLength), false))
        {
            throw std::runtime_error("buffer too short [E100]");
        }
        return position;
    }

    void sbePosition(const std::uint64_t position)
    {
        m_position = sbeCheckPosition(position);
    }

    SBE_NODISCARD std::uint64_t encodedLength() const SBE_NOEXCEPT
    {
        return sbePosition() - m_offset;
    }

    SBE_NODISCARD std::uint64_t decodeLength() const
    {
        Table skipper(m_buffer, m_offset, m_bufferLength, m_actingBlockLength, m_actingVersion);
        skipper.skip();
        return skipper.encodedLength();
    }

    SBE_NODISCARD const char *buffer() const SBE_NOEXCEPT
    {
        return m_buffer;
    }

    SBE_NODISCARD char *buffer() SBE_NOEXCEPT
    {
        return m_buffer;
    }

    SBE_NODISCARD std::uint64_t bufferLength() const SBE_NOEXCEPT
    {
        return m_bufferLength;
    }

    SBE_NODISCARD std::uint64_t actingVersion() const SBE_NOEXCEPT
    {
        return m_actingVersion;
    }

    SBE_NODISCARD static const char *f_float_0MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_0Id() SBE_NOEXCEPT
    {
        return 101;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_0SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_0InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_0EncodingOffset() SBE_NOEXCEPT
    {
        return 0;
    }

    static SBE_CONSTEXPR double f_float_0NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_0MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_0MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_0EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_0() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 0, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_0(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 0, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_1MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_1Id() SBE_NOEXCEPT
    {
        return 102;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_1SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_1InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_1EncodingOffset() SBE_NOEXCEPT
    {
        return 8;
    }

    static SBE_CONSTEXPR double f_float_1NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_1MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_1MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_1EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_1() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 8, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_1(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 8, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_2MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_2Id() SBE_NOEXCEPT
    {
        return 103;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_2SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_2InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_2EncodingOffset() SBE_NOEXCEPT
    {
        return 16;
    }

    static SBE_CONSTEXPR double f_float_2NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_2MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_2MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_2EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_2() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 16, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_2(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 16, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_3MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_3Id() SBE_NOEXCEPT
    {
        return 104;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_3SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_3InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_3EncodingOffset() SBE_NOEXCEPT
    {
        return 24;
    }

    static SBE_CONSTEXPR double f_float_3NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_3MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_3MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_3EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_3() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 24, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_3(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 24, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_4MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_4Id() SBE_NOEXCEPT
    {
        return 105;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_4SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_4InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_4EncodingOffset() SBE_NOEXCEPT
    {
        return 32;
    }

    static SBE_CONSTEXPR double f_float_4NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_4MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_4MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_4EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_4() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 32, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_4(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 32, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_5MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_5Id() SBE_NOEXCEPT
    {
        return 106;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_5SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_5InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_5EncodingOffset() SBE_NOEXCEPT
    {
        return 40;
    }

    static SBE_CONSTEXPR double f_float_5NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_5MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_5MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_5EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_5() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 40, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_5(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 40, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_6MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_6Id() SBE_NOEXCEPT
    {
        return 107;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_6SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_6InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_6EncodingOffset() SBE_NOEXCEPT
    {
        return 48;
    }

    static SBE_CONSTEXPR double f_float_6NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_6MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_6MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_6EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_6() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 48, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_6(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 48, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_7MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_7Id() SBE_NOEXCEPT
    {
        return 108;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_7SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_7InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_7EncodingOffset() SBE_NOEXCEPT
    {
        return 56;
    }

    static SBE_CONSTEXPR double f_float_7NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_7MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_7MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_7EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_7() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 56, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_7(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 56, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_8MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_8Id() SBE_NOEXCEPT
    {
        return 109;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_8SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_8InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_8EncodingOffset() SBE_NOEXCEPT
    {
        return 64;
    }

    static SBE_CONSTEXPR double f_float_8NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_8MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_8MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_8EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_8() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 64, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_8(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 64, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_9MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_9Id() SBE_NOEXCEPT
    {
        return 110;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_9SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_9InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_9EncodingOffset() SBE_NOEXCEPT
    {
        return 72;
    }

    static SBE_CONSTEXPR double f_float_9NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_9MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_9MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_9EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_9() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 72, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_9(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 72, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_10MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_10Id() SBE_NOEXCEPT
    {
        return 111;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_10SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_10InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_10EncodingOffset() SBE_NOEXCEPT
    {
        return 80;
    }

    static SBE_CONSTEXPR double f_float_10NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_10MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_10MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_10EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_10() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 80, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_10(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 80, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_11MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_11Id() SBE_NOEXCEPT
    {
        return 112;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_11SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_11InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_11EncodingOffset() SBE_NOEXCEPT
    {
        return 88;
    }

    static SBE_CONSTEXPR double f_float_11NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_11MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_11MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_11EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_11() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 88, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_11(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 88, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_12MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_12Id() SBE_NOEXCEPT
    {
        return 113;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_12SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_12InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_12EncodingOffset() SBE_NOEXCEPT
    {
        return 96;
    }

    static SBE_CONSTEXPR double f_float_12NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_12MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_12MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_12EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_12() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 96, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_12(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 96, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_13MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_13Id() SBE_NOEXCEPT
    {
        return 114;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_13SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_13InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_13EncodingOffset() SBE_NOEXCEPT
    {
        return 104;
    }

    static SBE_CONSTEXPR double f_float_13NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_13MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_13MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_13EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_13() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 104, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_13(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 104, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_14MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_14Id() SBE_NOEXCEPT
    {
        return 115;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_14SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_14InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_14EncodingOffset() SBE_NOEXCEPT
    {
        return 112;
    }

    static SBE_CONSTEXPR double f_float_14NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_14MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_14MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_14EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_14() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 112, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_14(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 112, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_float_15MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_float_15Id() SBE_NOEXCEPT
    {
        return 116;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_float_15SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_float_15InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_float_15EncodingOffset() SBE_NOEXCEPT
    {
        return 120;
    }

    static SBE_CONSTEXPR double f_float_15NullValue() SBE_NOEXCEPT
    {
        return SBE_DOUBLE_NAN;
    }

    static SBE_CONSTEXPR double f_float_15MinValue() SBE_NOEXCEPT
    {
        return -1.7976931348623157E308;
    }

    static SBE_CONSTEXPR double f_float_15MaxValue() SBE_NOEXCEPT
    {
        return 1.7976931348623157E308;
    }

    static SBE_CONSTEXPR std::size_t f_float_15EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD double f_float_15() const SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        std::memcpy(&val, m_buffer + m_offset + 120, sizeof(double));
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        return val.fp_value;
    }

    Table &f_float_15(const double value) SBE_NOEXCEPT
    {
        union sbe_double_as_uint_u val;
        val.fp_value = value;
        val.uint_value = SBE_LITTLE_ENDIAN_ENCODE_64(val.uint_value);
        std::memcpy(m_buffer + m_offset + 120, &val, sizeof(double));
        return *this;
    }

    SBE_NODISCARD static const char *f_int_0MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_int_0Id() SBE_NOEXCEPT
    {
        return 117;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_int_0SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_int_0InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_int_0EncodingOffset() SBE_NOEXCEPT
    {
        return 128;
    }

    static SBE_CONSTEXPR std::int64_t f_int_0NullValue() SBE_NOEXCEPT
    {
        return SBE_NULLVALUE_INT64;
    }

    static SBE_CONSTEXPR std::int64_t f_int_0MinValue() SBE_NOEXCEPT
    {
        return INT64_C(-9223372036854775807);
    }

    static SBE_CONSTEXPR std::int64_t f_int_0MaxValue() SBE_NOEXCEPT
    {
        return INT64_C(9223372036854775807);
    }

    static SBE_CONSTEXPR std::size_t f_int_0EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD std::int64_t f_int_0() const SBE_NOEXCEPT
    {
        std::int64_t val;
        std::memcpy(&val, m_buffer + m_offset + 128, sizeof(std::int64_t));
        return SBE_LITTLE_ENDIAN_ENCODE_64(val);
    }

    Table &f_int_0(const std::int64_t value) SBE_NOEXCEPT
    {
        std::int64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
        std::memcpy(m_buffer + m_offset + 128, &val, sizeof(std::int64_t));
        return *this;
    }

    SBE_NODISCARD static const char *f_int_1MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_int_1Id() SBE_NOEXCEPT
    {
        return 118;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_int_1SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_int_1InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_int_1EncodingOffset() SBE_NOEXCEPT
    {
        return 136;
    }

    static SBE_CONSTEXPR std::int64_t f_int_1NullValue() SBE_NOEXCEPT
    {
        return SBE_NULLVALUE_INT64;
    }

    static SBE_CONSTEXPR std::int64_t f_int_1MinValue() SBE_NOEXCEPT
    {
        return INT64_C(-9223372036854775807);
    }

    static SBE_CONSTEXPR std::int64_t f_int_1MaxValue() SBE_NOEXCEPT
    {
        return INT64_C(9223372036854775807);
    }

    static SBE_CONSTEXPR std::size_t f_int_1EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD std::int64_t f_int_1() const SBE_NOEXCEPT
    {
        std::int64_t val;
        std::memcpy(&val, m_buffer + m_offset + 136, sizeof(std::int64_t));
        return SBE_LITTLE_ENDIAN_ENCODE_64(val);
    }

    Table &f_int_1(const std::int64_t value) SBE_NOEXCEPT
    {
        std::int64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
        std::memcpy(m_buffer + m_offset + 136, &val, sizeof(std::int64_t));
        return *this;
    }

    SBE_NODISCARD static const char *f_int_2MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_int_2Id() SBE_NOEXCEPT
    {
        return 119;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_int_2SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_int_2InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_int_2EncodingOffset() SBE_NOEXCEPT
    {
        return 144;
    }

    static SBE_CONSTEXPR std::int64_t f_int_2NullValue() SBE_NOEXCEPT
    {
        return SBE_NULLVALUE_INT64;
    }

    static SBE_CONSTEXPR std::int64_t f_int_2MinValue() SBE_NOEXCEPT
    {
        return INT64_C(-9223372036854775807);
    }

    static SBE_CONSTEXPR std::int64_t f_int_2MaxValue() SBE_NOEXCEPT
    {
        return INT64_C(9223372036854775807);
    }

    static SBE_CONSTEXPR std::size_t f_int_2EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD std::int64_t f_int_2() const SBE_NOEXCEPT
    {
        std::int64_t val;
        std::memcpy(&val, m_buffer + m_offset + 144, sizeof(std::int64_t));
        return SBE_LITTLE_ENDIAN_ENCODE_64(val);
    }

    Table &f_int_2(const std::int64_t value) SBE_NOEXCEPT
    {
        std::int64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
        std::memcpy(m_buffer + m_offset + 144, &val, sizeof(std::int64_t));
        return *this;
    }

    SBE_NODISCARD static const char *f_int_3MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static SBE_CONSTEXPR std::uint16_t f_int_3Id() SBE_NOEXCEPT
    {
        return 120;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::uint64_t f_int_3SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    SBE_NODISCARD bool f_int_3InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    SBE_NODISCARD static SBE_CONSTEXPR std::size_t f_int_3EncodingOffset() SBE_NOEXCEPT
    {
        return 152;
    }

    static SBE_CONSTEXPR std::int64_t f_int_3NullValue() SBE_NOEXCEPT
    {
        return SBE_NULLVALUE_INT64;
    }

    static SBE_CONSTEXPR std::int64_t f_int_3MinValue() SBE_NOEXCEPT
    {
        return INT64_C(-9223372036854775807);
    }

    static SBE_CONSTEXPR std::int64_t f_int_3MaxValue() SBE_NOEXCEPT
    {
        return INT64_C(9223372036854775807);
    }

    static SBE_CONSTEXPR std::size_t f_int_3EncodingLength() SBE_NOEXCEPT
    {
        return 8;
    }

    SBE_NODISCARD std::int64_t f_int_3() const SBE_NOEXCEPT
    {
        std::int64_t val;
        std::memcpy(&val, m_buffer + m_offset + 152, sizeof(std::int64_t));
        return SBE_LITTLE_ENDIAN_ENCODE_64(val);
    }

    Table &f_int_3(const std::int64_t value) SBE_NOEXCEPT
    {
        std::int64_t val = SBE_LITTLE_ENDIAN_ENCODE_64(value);
        std::memcpy(m_buffer + m_offset + 152, &val, sizeof(std::int64_t));
        return *this;
    }

    SBE_NODISCARD static const char *f_str_0MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static const char *f_str_0CharacterEncoding() SBE_NOEXCEPT
    {
        return "UTF-8";
    }

    static SBE_CONSTEXPR std::uint64_t f_str_0SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    bool f_str_0InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    static SBE_CONSTEXPR std::uint16_t f_str_0Id() SBE_NOEXCEPT
    {
        return 121;
    }

    static SBE_CONSTEXPR std::uint64_t f_str_0HeaderLength() SBE_NOEXCEPT
    {
        return 4;
    }

    SBE_NODISCARD std::uint32_t f_str_0Length() const
    {
        std::uint32_t length;
        std::memcpy(&length, m_buffer + sbePosition(), sizeof(std::uint32_t));
        return SBE_LITTLE_ENDIAN_ENCODE_32(length);
    }

    std::uint64_t skipF_str_0()
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + lengthPosition, sizeof(std::uint32_t));
        std::uint64_t dataLength = SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue);
        sbePosition(lengthPosition + lengthOfLengthField + dataLength);
        return dataLength;
    }

    SBE_NODISCARD const char *f_str_0()
    {
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + sbePosition(), sizeof(std::uint32_t));
        const char *fieldPtr = m_buffer + sbePosition() + 4;
        sbePosition(sbePosition() + 4 + SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue));
        return fieldPtr;
    }

    std::uint64_t getF_str_0(char *dst, const std::uint64_t length)
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        sbePosition(lengthPosition + lengthOfLengthField);
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + lengthPosition, sizeof(std::uint32_t));
        std::uint64_t dataLength = SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue);
        std::uint64_t bytesToCopy = length < dataLength ? length : dataLength;
        std::uint64_t pos = sbePosition();
        sbePosition(pos + dataLength);
        std::memcpy(dst, m_buffer + pos, static_cast<std::size_t>(bytesToCopy));
        return bytesToCopy;
    }

    Table &putF_str_0(const char *src, const std::uint32_t length)
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        std::uint32_t lengthFieldValue = SBE_LITTLE_ENDIAN_ENCODE_32(length);
        sbePosition(lengthPosition + lengthOfLengthField);
        std::memcpy(m_buffer + lengthPosition, &lengthFieldValue, sizeof(std::uint32_t));
        if (length != std::uint32_t(0))
        {
            std::uint64_t pos = sbePosition();
            sbePosition(pos + length);
            std::memcpy(m_buffer + pos, src, length);
        }
        return *this;
    }

    std::string getF_str_0AsString()
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        sbePosition(lengthPosition + lengthOfLengthField);
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + lengthPosition, sizeof(std::uint32_t));
        std::uint64_t dataLength = SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue);
        std::uint64_t pos = sbePosition();
        const std::string result(m_buffer + pos, dataLength);
        sbePosition(pos + dataLength);
        return result;
    }

    std::string getF_str_0AsJsonEscapedString()
    {
        std::ostringstream oss;
        std::string s = getF_str_0AsString();

        for (const auto c : s)
        {
            switch (c)
            {
                case '"': oss << "\\\""; break;
                case '\\': oss << "\\\\"; break;
                case '\b': oss << "\\b"; break;
                case '\f': oss << "\\f"; break;
                case '\n': oss << "\\n"; break;
                case '\r': oss << "\\r"; break;
                case '\t': oss << "\\t"; break;

                default:
                    if ('\x00' <= c && c <= '\x1f')
                    {
                        oss << "\\u" << std::hex << std::setw(4)
                            << std::setfill('0') << (int)(c);
                    }
                    else
                    {
                        oss << c;
                    }
            }
        }

        return oss.str();
    }

    #ifdef SBE_USE_STRING_VIEW
    std::string_view getF_str_0AsStringView()
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        sbePosition(lengthPosition + lengthOfLengthField);
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + lengthPosition, sizeof(std::uint32_t));
        std::uint64_t dataLength = SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue);
        std::uint64_t pos = sbePosition();
        const std::string_view result(m_buffer + pos, dataLength);
        sbePosition(pos + dataLength);
        return result;
    }
    #endif

    Table &putF_str_0(const std::string &str)
    {
        if (str.length() > 1073741824)
        {
            throw std::runtime_error("std::string too long for length type [E109]");
        }
        return putF_str_0(str.data(), static_cast<std::uint32_t>(str.length()));
    }

    #ifdef SBE_USE_STRING_VIEW
    Table &putF_str_0(const std::string_view str)
    {
        if (str.length() > 1073741824)
        {
            throw std::runtime_error("std::string too long for length type [E109]");
        }
        return putF_str_0(str.data(), static_cast<std::uint32_t>(str.length()));
    }
    #endif

    SBE_NODISCARD static const char *f_str_1MetaAttribute(const MetaAttribute metaAttribute) SBE_NOEXCEPT
    {
        switch (metaAttribute)
        {
            case MetaAttribute::PRESENCE: return "required";
            default: return "";
        }
    }

    static const char *f_str_1CharacterEncoding() SBE_NOEXCEPT
    {
        return "UTF-8";
    }

    static SBE_CONSTEXPR std::uint64_t f_str_1SinceVersion() SBE_NOEXCEPT
    {
        return 0;
    }

    bool f_str_1InActingVersion() SBE_NOEXCEPT
    {
        return true;
    }

    static SBE_CONSTEXPR std::uint16_t f_str_1Id() SBE_NOEXCEPT
    {
        return 122;
    }

    static SBE_CONSTEXPR std::uint64_t f_str_1HeaderLength() SBE_NOEXCEPT
    {
        return 4;
    }

    SBE_NODISCARD std::uint32_t f_str_1Length() const
    {
        std::uint32_t length;
        std::memcpy(&length, m_buffer + sbePosition(), sizeof(std::uint32_t));
        return SBE_LITTLE_ENDIAN_ENCODE_32(length);
    }

    std::uint64_t skipF_str_1()
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + lengthPosition, sizeof(std::uint32_t));
        std::uint64_t dataLength = SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue);
        sbePosition(lengthPosition + lengthOfLengthField + dataLength);
        return dataLength;
    }

    SBE_NODISCARD const char *f_str_1()
    {
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + sbePosition(), sizeof(std::uint32_t));
        const char *fieldPtr = m_buffer + sbePosition() + 4;
        sbePosition(sbePosition() + 4 + SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue));
        return fieldPtr;
    }

    std::uint64_t getF_str_1(char *dst, const std::uint64_t length)
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        sbePosition(lengthPosition + lengthOfLengthField);
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + lengthPosition, sizeof(std::uint32_t));
        std::uint64_t dataLength = SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue);
        std::uint64_t bytesToCopy = length < dataLength ? length : dataLength;
        std::uint64_t pos = sbePosition();
        sbePosition(pos + dataLength);
        std::memcpy(dst, m_buffer + pos, static_cast<std::size_t>(bytesToCopy));
        return bytesToCopy;
    }

    Table &putF_str_1(const char *src, const std::uint32_t length)
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        std::uint32_t lengthFieldValue = SBE_LITTLE_ENDIAN_ENCODE_32(length);
        sbePosition(lengthPosition + lengthOfLengthField);
        std::memcpy(m_buffer + lengthPosition, &lengthFieldValue, sizeof(std::uint32_t));
        if (length != std::uint32_t(0))
        {
            std::uint64_t pos = sbePosition();
            sbePosition(pos + length);
            std::memcpy(m_buffer + pos, src, length);
        }
        return *this;
    }

    std::string getF_str_1AsString()
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        sbePosition(lengthPosition + lengthOfLengthField);
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + lengthPosition, sizeof(std::uint32_t));
        std::uint64_t dataLength = SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue);
        std::uint64_t pos = sbePosition();
        const std::string result(m_buffer + pos, dataLength);
        sbePosition(pos + dataLength);
        return result;
    }

    std::string getF_str_1AsJsonEscapedString()
    {
        std::ostringstream oss;
        std::string s = getF_str_1AsString();

        for (const auto c : s)
        {
            switch (c)
            {
                case '"': oss << "\\\""; break;
                case '\\': oss << "\\\\"; break;
                case '\b': oss << "\\b"; break;
                case '\f': oss << "\\f"; break;
                case '\n': oss << "\\n"; break;
                case '\r': oss << "\\r"; break;
                case '\t': oss << "\\t"; break;

                default:
                    if ('\x00' <= c && c <= '\x1f')
                    {
                        oss << "\\u" << std::hex << std::setw(4)
                            << std::setfill('0') << (int)(c);
                    }
                    else
                    {
                        oss << c;
                    }
            }
        }

        return oss.str();
    }

    #ifdef SBE_USE_STRING_VIEW
    std::string_view getF_str_1AsStringView()
    {
        std::uint64_t lengthOfLengthField = 4;
        std::uint64_t lengthPosition = sbePosition();
        sbePosition(lengthPosition + lengthOfLengthField);
        std::uint32_t lengthFieldValue;
        std::memcpy(&lengthFieldValue, m_buffer + lengthPosition, sizeof(std::uint32_t));
        std::uint64_t dataLength = SBE_LITTLE_ENDIAN_ENCODE_32(lengthFieldValue);
        std::uint64_t pos = sbePosition();
        const std::string_view result(m_buffer + pos, dataLength);
        sbePosition(pos + dataLength);
        return result;
    }
    #endif

    Table &putF_str_1(const std::string &str)
    {
        if (str.length() > 1073741824)
        {
            throw std::runtime_error("std::string too long for length type [E109]");
        }
        return putF_str_1(str.data(), static_cast<std::uint32_t>(str.length()));
    }

    #ifdef SBE_USE_STRING_VIEW
    Table &putF_str_1(const std::string_view str)
    {
        if (str.length() > 1073741824)
        {
            throw std::runtime_error("std::string too long for length type [E109]");
        }
        return putF_str_1(str.data(), static_cast<std::uint32_t>(str.length()));
    }
    #endif

template<typename CharT, typename Traits>
friend std::basic_ostream<CharT, Traits> & operator << (
    std::basic_ostream<CharT, Traits> &builder, const Table &_writer)
{
    Table writer(
        _writer.m_buffer,
        _writer.m_offset,
        _writer.m_bufferLength,
        _writer.m_actingBlockLength,
        _writer.m_actingVersion);

    builder << '{';
    builder << R"("Name": "Table", )";
    builder << R"("sbeTemplateId": )";
    builder << writer.sbeTemplateId();
    builder << ", ";

    builder << R"("f_float_0": )";
    builder << +writer.f_float_0();

    builder << ", ";
    builder << R"("f_float_1": )";
    builder << +writer.f_float_1();

    builder << ", ";
    builder << R"("f_float_2": )";
    builder << +writer.f_float_2();

    builder << ", ";
    builder << R"("f_float_3": )";
    builder << +writer.f_float_3();

    builder << ", ";
    builder << R"("f_float_4": )";
    builder << +writer.f_float_4();

    builder << ", ";
    builder << R"("f_float_5": )";
    builder << +writer.f_float_5();

    builder << ", ";
    builder << R"("f_float_6": )";
    builder << +writer.f_float_6();

    builder << ", ";
    builder << R"("f_float_7": )";
    builder << +writer.f_float_7();

    builder << ", ";
    builder << R"("f_float_8": )";
    builder << +writer.f_float_8();

    builder << ", ";
    builder << R"("f_float_9": )";
    builder << +writer.f_float_9();

    builder << ", ";
    builder << R"("f_float_10": )";
    builder << +writer.f_float_10();

    builder << ", ";
    builder << R"("f_float_11": )";
    builder << +writer.f_float_11();

    builder << ", ";
    builder << R"("f_float_12": )";
    builder << +writer.f_float_12();

    builder << ", ";
    builder << R"("f_float_13": )";
    builder << +writer.f_float_13();

    builder << ", ";
    builder << R"("f_float_14": )";
    builder << +writer.f_float_14();

    builder << ", ";
    builder << R"("f_float_15": )";
    builder << +writer.f_float_15();

    builder << ", ";
    builder << R"("f_int_0": )";
    builder << +writer.f_int_0();

    builder << ", ";
    builder << R"("f_int_1": )";
    builder << +writer.f_int_1();

    builder << ", ";
    builder << R"("f_int_2": )";
    builder << +writer.f_int_2();

    builder << ", ";
    builder << R"("f_int_3": )";
    builder << +writer.f_int_3();

    builder << ", ";
    builder << R"("f_str_0": )";
    builder << '"' <<
        writer.getF_str_0AsJsonEscapedString().c_str() << '"';

    builder << ", ";
    builder << R"("f_str_1": )";
    builder << '"' <<
        writer.getF_str_1AsJsonEscapedString().c_str() << '"';

    builder << '}';

    return builder;
}

void skip()
{
    skipF_str_0();
    skipF_str_1();
}

SBE_NODISCARD static SBE_CONSTEXPR bool isConstLength() SBE_NOEXCEPT
{
    return false;
}

SBE_NODISCARD static std::size_t computeLength(
    std::size_t f_str_0Length = 0,
    std::size_t f_str_1Length = 0)
{
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wtype-limits"
#endif
    std::size_t length = sbeBlockLength();

    length += f_str_0HeaderLength();
    if (f_str_0Length > 1073741824LL)
    {
        throw std::runtime_error("f_str_0Length too long for length type [E109]");
    }
    length += f_str_0Length;

    length += f_str_1HeaderLength();
    if (f_str_1Length > 1073741824LL)
    {
        throw std::runtime_error("f_str_1Length too long for length type [E109]");
    }
    length += f_str_1Length;

    return length;
#if defined(__GNUG__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
}
};
}
}
#endif
