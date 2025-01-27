const tokenize = @import("../tokenize.zig");
const std = @import("std");

const Token = tokenize.Token;

pub const Texts = [_][]const u8{
    "comptime", "extern", "inline", "opaque", "packed",
    "struct",   "const",  "defer",  "error",  "match",
    "union",    "break",  "else",   "loop",   "next",
    "type",     "yeet",   "and",    "any",    "not",
    "pub",      "as",     "fn",     "if",     "or",
};

pub const Masks = blk: {
    // TODO: Credit @validark / whomever they got this from.

    // A keyword hash is represented as a 7-bit integer, meaning it can represent values within the range of 0-127.
    // With this information, we can use the 128 possible values in a hash to set a bit in a 128-bit bitmask.
    //
    // For example: With a 32-bit bitmask and a 5-bit hash.
    //
    //  Hash: 00010 # Set the 2nd bit in the mask.
    //  Hash: 10100 # Set the 20th bit in the mask.
    //  Hash: 00111 # Set the 7th bit in the mask.
    //  Mask: 01000010'00000000'00010000'00000000
    //
    // Now, in order to check if a given hash is in our mask, we check the n-th bit of our mask is set.
    // For ease of use, we represent this 128-bit mask as an array of 2 u64's.
    var bitmask = [_]u64{0} ** 2;

    for (Texts) |kw| {
        const hash = hashSlice(kw);

        // In order to check if a bit in the mask is set, we can perform the following:
        //  bitmask[hash / 64] >> hash.
        //
        // Since the hash can only represent values between 0-127, dividing by 64 will always
        // result in either a 0 or 1 selecting either the upper (0), or lower (1) 64 bits in the
        // bitmask array.
        //
        // Shifting this value by the hash amount will check if the bit at the hash index is set.
        switch (@as(u1, @truncate(bitmask[hash / 64] >> @truncate(hash)))) {
            // If the selected bit has not been set, set it.
            0 => bitmask[hash / 64] |= @as(u64, 1) << @truncate(hash),
            // If the selected bit has already been set, unset it.
            // This will be used to detect hash collisions.
            1 => bitmask[hash / 64] &= ~(@as(u64, 1) << @truncate(hash)),
        }
    }

    // This routine can be used to check for hash collisions in our table at compile time.
    // Since the goal of the above code was to set a bit for every unique hash in our keywords,
    // we can perform a popcount to query the number of set bits in our mask.
    // If this number is not equal to the amount of keywords we were attempting to hash,
    // we know that we have encountered a hash collision.
    if (@popCount(bitmask[0]) + @popCount(bitmask[1]) != Texts.len) {
        var err: []const u8 = "Hash collisions detected:\n";
        for (Texts) |kw| {
            const hash = hashSlice(kw);

            // Figure out which of the bits that should be set are unset. These are the collided hashes.
            switch (@as(u1, @truncate(bitmask[hash / 64] >> @truncate(hash)))) {
                0 => err = err ++ std.fmt.comptimePrint("'{s}' => `{}`\n", .{ kw, hash }),
                1 => {},
            }
        }
        @compileError(err);
    }

    break :blk bitmask;
};

pub const PaddedTexts = blk: {
    // In order to efficiently lookup a keyword, we rely on the guarantee that the maximum keyword length is 8 characters.
    // For keywords that are less than 8 keywords, we pad the remaining characters with 0 so we don't compare against garbage.
    std.debug.assert(MaxLen == 8);

    var padded: [Texts.len][]const u8 = undefined;
    for (Texts) |kw| {
        const hash = hashSlice(kw);
        const index = hashToIndex(hash);

        padded[index] = kw ++ "\x00" ** (MaxLen - kw.len);
    }

    break :blk padded;
};

pub const MaxLen = blk: {
    var max = 0;
    for (Texts) |kw| max = @max(kw.len, max);
    break :blk max;
};

pub fn hashSlice(text: []const u8) u7 {
    // TODO: Credit @validark / whomever they got this from.

    // Since we can guarantee that every keyword's first and last two characters are unique, we can use them as a hash.
    // However, for our unique hash table, we must map the unique 32-bits of our keywords to a unique 7-bits.
    // This does introduce the ability for hash collisions for unique keywords, but this can be caught at comptime.
    std.debug.assert(text.len > 0);

    const span = if (@inComptime())
        // At compile time, we know that the text must have a length of at least two.
        text[text.len - 2 .. text.len][0..2]
    else
        // At runtime, the text can have a size of at least one, but due to other contraints, it is safe to index past the slice bounds.
        (text.ptr - 2 + text.len)[0..2];

    // Read the first two characters in the text. Check the Back padding to ensure we can read past the slice bounds.
    comptime std.debug.assert(tokenize.BackPad.len >= 1);
    const lo = std.mem.readInt(u16, text.ptr[0..2], .little);

    // Read the last two characters in the text. Check the Front padding to ensure we can read before the slice bounds.
    comptime std.debug.assert(tokenize.FrontPad.len >= 1);
    const hi = std.mem.readInt(u16, span.ptr[0..2], .little);

    // Do some math stuff that will make the hashes for hashy. Idk. Ask @validark.
    // TODO: Perchance look into `pext` on x86 for hashing. could be faster and fewer instructions.
    return @truncate(((lo ^ (text.len << 14)) *% hi) >> 8);
}

pub fn hashToIndex(hash: u7) u8 {
    // TODO: Credit @validark / whomever they got this from.

    const mask = (@as(u64, 1) << @truncate(hash)) -% 1;
    return (if (hash >= 64)
        comptime @popCount(Masks[0])
    else
        0) + @popCount(mask & Masks[hash / 64]);
}

pub fn indexToTag(index: u8) Token.Tag {
    return @enumFromInt(~index);
}

pub fn lookup(text: []const u8) ?Token.Tag {
    // TODO: The unaligned load from `text.ptr[0..8]` doesn't really matter on x86. But on other platforms this could incur a non-insignificant runtime cost.
    // TODO: See if the compiler is smart and can figure out the nullity of this lookup function will be Tag.Identifier.

    // Hash the provided key and load the expected value.
    const hash = hashSlice(text);
    const index = hashToIndex(hash);
    const kw = PaddedTexts[index];

    // We still have to check whether the provided key and the expected value are the same. This would normally be a slow string comparison, but we have special guarantees we can abuse.
    // Firstly, all keywords can fit into a 64-bit integer, so the key, value comparison can be an integer comparison.
    // Secondly, when loading a source file, we insert padding into the end so even if `text.ptr[0..8]` is out of bounds of the source text, we would end up reading from the padding.
    // However, we still have the issue when loading `text.ptr[0..8]`, we could read data we don't want to compare against. We can mask out the unwanted bytes in a process shown below.
    //
    // Keyw: "struct  "
    // Text: "struct {" # We don't want to compare against ` {`
    // Mask:  11111100
    //
    // Keyw == Text & Mask

    // TODO: Improve the mask generation.
    const mask = if (text.len == 8) ~@as(u64, 0) else (@as(u64, 1) << @truncate(text.len * 8)) -% 1;
    const text_int = std.mem.readInt(u64, text.ptr[0..8], .little);
    const kw_int = std.mem.readInt(u64, kw.ptr[0..8], .little);

    std.debug.print("LOOKUP: \n", .{});
    std.debug.print("  {b:0>64}\n", .{@bitReverse(text_int)});
    std.debug.print("  {b:0>64}\n", .{@bitReverse(mask)});
    std.debug.print("  {b:0>64}\n\n", .{@bitReverse(kw_int)});

    return if (text_int & mask == kw_int) indexToTag(index) else null;
}
