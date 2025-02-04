const tokenize = @import("../tokenize.zig");
const std = @import("std");

const Token = tokenize.Token;

pub const Texts = [_][]const u8{
    "(",  ")",   "{",   "}",   "[",  "]",
    ".",  "..",  "...", ":",   ",",  "?",
    "+",  "+=",  "++",  "-",   "-=", "*",
    "*=", "**",  "/",   "/=",  "//", "///",
    "&",  "&=",  "&&",  "|",   "|=", "||",
    "^",  "^=",  "%",   "%=",  "=",  "==",
    "!",  "!=",  "<",   "<=",  ">",  ">=",
    "<<", "<<=", ">>",  ">>=",
};

// TODO: DRY with Keywords impl.
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

const PaddedTexts = blk: {
    std.debug.assert(MaxLen == 4);

    var padded: [Texts.len][]const u8 = undefined;
    for (Texts) |op| {
        const hash = hashSlice(op);
        const index = hashToIndex(hash);

        padded[index] = op ++ "\x00" ** (MaxLen - op.len);
    }

    break :blk padded;
};

// TODO: DRY with Keywords impl.
pub const MaxLen = 4;
// pub const MaxLen = blk: {
//     var max = 0;
//     for (Texts) |op| max = @max(op.len, max);
//     break :blk max;
// };

pub fn hashSlice(text: []const u8) u7 {
    // TODO: Credit @validark. Where tf is he finding this??
    comptime std.debug.assert(tokenize.BackPad.len >= 3);

    const shift = text.len * 8;
    const mask: u32 = @intCast((@as(u64, 1) << @intCast(shift)) -% 1);

    const span = if (@inComptime())
        (text ++ "\x00" ** 3)
    else
        text.ptr;

    const op = std.mem.readInt(u32, span[0..MaxLen], .little) & mask;

    return @intCast(((op *% 698839068) -% comptime (@as(u32, 29) << 25)) >> 25);
}

pub fn hashToIndex(hash: u7) u8 {
    const mask = (@as(u64, 1) << @truncate(hash)) -% 1;
    return (if (hash >= 64) (comptime @popCount(Masks[0])) else 0) + @popCount(mask & Masks[hash / 64]);
}

pub fn indexToTag(index: u8) Token.Tag {
    return @enumFromInt(index);
}

pub fn lookup(text: []const u8) ?Token.Tag {
    std.debug.assert(text.len <= MaxLen);

    const hash = hashSlice(text);
    const index = hashToIndex(hash);
    const op = PaddedTexts[index];

    const mask = (@as(u32, 1) << @truncate(text.len * 8)) -% 1;
    const text_int = std.mem.readInt(u32, text.ptr[0..MaxLen], .little);
    const op_int = std.mem.readInt(u32, op[0..MaxLen], .little);

    return if (text_int & mask == op_int) indexToTag(index) else null;
}
