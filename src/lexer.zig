const std = @import("std");
const testing = std.testing;
const mem = std.mem;

pub const Token = struct {
    start_pos: u32,
    len: u24 = 1,
    kind: Kind,
    pub const Kind = enum {
        illegal,
        eof,

        // Identifiers & literals
        ident,
        int,
        string, // contains the string delims

        // op
        assign,
        plus,
        minus,
        eq,
        neq,
        lt,
        gt,
        ge,
        le,
        slash,
        star,
        bang,
        percent,

        // Delimiters
        lparen,
        rparen,
        lbrace,
        rbrace,
        lbracket,
        rbracket,
        semicolon,
        comma,
        dot,
        colon,

        // Keywords
        func,
        let,
        @"if",
        @"else",
        @"return",
        @"true",
        @"false",
        @"nil",
        @"for",
    };

    /// like parsePos, but starts at offset 0
    pub fn parse(input: []const u8) Token {
        return Token.parsePos(input, 0);
    }

    /// parse the next token from offset
    pub fn parsePos(input: []const u8, offset: u32) Token {
        if (offset > input.len) return Token{ .kind = .eof, .start_pos = offset };
        if (switch (input[offset]) {
            '(' => Token{ .kind = .lparen, .start_pos = offset },
            ')' => Token{ .kind = .rparen, .start_pos = offset },
            '{' => Token{ .kind = .lbracket, .start_pos = offset },
            '}' => Token{ .kind = .rbracket, .start_pos = offset },
            '[' => Token{ .kind = .lbrace, .start_pos = offset },
            ']' => Token{ .kind = .rbrace, .start_pos = offset },
            ';' => Token{ .kind = .semicolon, .start_pos = offset },
            ',' => Token{ .kind = .comma, .start_pos = offset },
            '.' => Token{ .kind = .dot, .start_pos = offset },
            ':' => Token{ .kind = .colon, .start_pos = offset },
            '+' => Token{ .kind = .plus, .start_pos = offset },
            '=' => if (offset + 1 < input.len and input[offset + 1] == '=')
                return Token{ .kind = .eq, .start_pos = offset, .len = 2 }
            else
                Token{ .kind = .assign, .start_pos = offset },
            '-' => Token{ .kind = .minus, .start_pos = offset },
            '<' => if (offset + 1 < input.len and input[offset + 1] == '=')
                return Token{ .kind = .le, .start_pos = offset, .len = 2 }
            else
                Token{ .kind = .lt, .start_pos = offset },
            '>' => if (offset + 1 < input.len and input[offset + 1] == '=')
                return Token{ .kind = .ge, .start_pos = offset, .len = 2 }
            else
                Token{ .kind = .gt, .start_pos = offset },
            '*' => Token{ .kind = .star, .start_pos = offset },
            '/' => Token{ .kind = .slash, .start_pos = offset },
            '%' => Token{ .kind = .percent, .start_pos = offset },
            '!' => if (offset + 1 < input.len and input[offset + 1] == '=')
                Token{ .kind = .neq, .start_pos = offset, .len = 2 }
            else
                Token{ .kind = .bang, .start_pos = offset },
            '"' => {
                var i: u32 = offset + 1;
                while (i < input.len and (input[i] != '"' or input[i - 1] == '\\')) : (i += 1) {}

                if (i == input.len) return Token{ .kind = .illegal, .start_pos = offset, .len = 0 };
                return Token{ .kind = .string, .start_pos = offset, .len = @intCast(u24, i - offset + 1) };
            },
            else => null,
        }) |tok| return tok;

        var tokenizer = mem.tokenize(u8, input[offset..], " \t\n\r;(){}[],.:+=+*-/%");
        const t = if (tokenizer.next()) |n| n else return Token{ .kind = .eof, .start_pos = offset, .len = 0 };

        return if (mem.eql(u8, t, "let"))
            Token{ .kind = .let, .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "fn"))
            Token{ .kind = .func, .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (containsOnlyAnyOf(u8, t, "0123456789"))
            Token{ .kind = .int, .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "<="))
            Token{ .kind = .le, .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, ">="))
            Token{ .kind = .ge, .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "=="))
            Token{ .kind = .eq, .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "!="))
            Token{ .kind = .neq, .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "true"))
            Token{ .kind = .@"true", .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "false"))
            Token{ .kind = .@"false", .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "nil"))
            Token{ .kind = .@"nil", .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "if"))
            Token{ .kind = .@"if", .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "else"))
            Token{ .kind = .@"else", .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "return"))
            Token{ .kind = .@"return", .start_pos = offset, .len = @intCast(u24, t.len) }
        else if (mem.eql(u8, t, "for"))
            Token{ .kind = .@"for", .start_pos = offset, .len = @intCast(u24, t.len) }
        else
            Token{ .kind = .ident, .start_pos = offset, .len = @intCast(u24, t.len) };
    }

    pub fn string(t: Token, input: []const u8) []const u8 {
        return input[t.start_pos..(t.start_pos + t.len)];
    }

    /// Returns the line & column of the given position in the input.
    /// One indexed
    const FilePos = struct {
        line: u32 = 1,
        col: u32 = 1,
    };

    pub fn filePos(t: Token, input: []const u8) FilePos {
        var f = FilePos{};

        for (input[0..t.start_pos]) |c| {
            if (c == '\n') {
                f.line += 1;
                f.col = 1;
            } else f.col += 1;
        }

        return f;
    }

    test "file pos" {
        var input =
            \\let foo = "bar";
            \\if ("baz" != "")
        ;
        var tok = Token.parsePos(input, 21);
        try testing.expectEqual(tok.filePos(input), FilePos{ .line = 2, .col = 5 });
    }
};

fn containsOnlyAnyOf(comptime T: type, haystack: []const T, needle_stack: []const T) bool {
    for (haystack) |x| {
        for (needle_stack) |y| {
            if (x == y) break;
        } else return false;
    }
    return true;
}

test "containsOnlyAnyOf" {
    try testing.expect(containsOnlyAnyOf(u8, "15632", "0123456789"));
    try testing.expect(containsOnlyAnyOf(u8, "abc", "abcd"));
    try testing.expect(!containsOnlyAnyOf(u8, "abc", "ab"));
}

pub const Lexer = struct {
    input: []const u8,
    offset: u32 = 0,

    const Self = @This();
    pub fn init(input: []const u8) Self {
        return Self{ .input = input };
    }

    pub fn next(self: *Self) Token {
        while (self.offset < self.input.len) {
            self.eatWhileAnyOf(" \t\r\n");
            const t = Token.parsePos(self.input, self.offset);
            self.offset += t.len;
            return t;
        }

        return Token{ .kind = .eof, .start_pos = self.offset, .len = 0 };
    }

    fn eatWhileAnyOf(self: *Self, needle_stack: []const u8) void {
        while (self.offset + 1 < self.input.len) : (self.offset += 1) {
            if (!containsOnlyAnyOf(u8, self.input[self.offset .. self.offset + 1], needle_stack)) break;
        }
    }
};

test "empty" {
    var l = Lexer.init("");
    try testing.expect(l.next().kind == .eof);
}

test ";;;" {
    var l = Lexer.init(";;;");
    try testing.expect(l.next().kind == .semicolon);
    try testing.expect(l.next().kind == .semicolon);
    try testing.expect(l.next().kind == .semicolon);
    try testing.expect(l.next().kind == .eof);
}

test "let" {
    var l = Lexer.init("let");
    try testing.expectEqual(l.next(), Token{ .kind = .let, .start_pos = 0, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .eof, .start_pos = 3, .len = 0 });
}

test "let expr" {
    var l = Lexer.init("let a = 27;");
    try testing.expectEqual(l.next(), Token{ .kind = .let, .start_pos = 0, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 4 });
    try testing.expectEqual(l.next(), Token{ .kind = .assign, .start_pos = 6 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 8, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 10 });
    try testing.expectEqual(l.next(), Token{ .kind = .eof, .start_pos = 11, .len = 0 });
}

test "let string" {
    var l = Lexer.init(
        \\let hello_world = "hello world";
    );
    try testing.expectEqual(l.next(), Token{ .kind = .let, .start_pos = 0, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 4, .len = 11 });
    try testing.expectEqual(l.next(), Token{ .kind = .assign, .start_pos = 16 });
    const hello_world = l.next();
    try testing.expectEqual(hello_world, Token{ .kind = .string, .start_pos = 18, .len = 13 });
    try testing.expectEqualStrings(hello_world.string(l.input), "\"hello world\"");
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 31 });
}

test "math" {
    var l = Lexer.init("let y = 7*7 + 42/2 - 14 % 5;");
    try testing.expectEqual(l.next(), Token{ .kind = .let, .start_pos = 0, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 4 });
    try testing.expectEqual(l.next(), Token{ .kind = .assign, .start_pos = 6 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 8 });
    try testing.expectEqual(l.next(), Token{ .kind = .star, .start_pos = 9 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 10 });
    try testing.expectEqual(l.next(), Token{ .kind = .plus, .start_pos = 12 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 14, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .slash, .start_pos = 16 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 17 });
    try testing.expectEqual(l.next(), Token{ .kind = .minus, .start_pos = 19 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 21, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .percent, .start_pos = 24 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 26 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 27 });
}

test "escaped string" {
    var l = Lexer.init(
        \\"\"hello world\""
    );
    const hello_world = l.next();
    try testing.expectEqual(hello_world, Token{ .kind = .string, .start_pos = 0, .len = 17 });
    try testing.expectEqualStrings(hello_world.string(l.input), l.input);
}

test "most of the syntax" {
    var l = Lexer.init(
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
        \\!-/*5;
        \\5 < 10 > 5;
        \\
        \\if (5 < 10) {
        \\  return true;
        \\} else {
        \\  return false;
        \\}
        \\
        \\10 == 10;
        \\10 != 9;
        \\5 <= 10;
        \\12 >= 10;
    );
    try testing.expectEqual(l.next(), Token{ .kind = .let, .start_pos = 0, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 4, .len = 4 });
    try testing.expectEqual(l.next(), Token{ .kind = .assign, .start_pos = 9 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 11 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 12 });
    try testing.expectEqual(l.next(), Token{ .kind = .let, .start_pos = 14, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 18, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .assign, .start_pos = 22 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 24, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 26 });
    try testing.expectEqual(l.next(), Token{ .kind = .let, .start_pos = 29, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 33, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .assign, .start_pos = 37 });
    try testing.expectEqual(l.next(), Token{ .kind = .func, .start_pos = 39, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .lparen, .start_pos = 41 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 42 });
    try testing.expectEqual(l.next(), Token{ .kind = .comma, .start_pos = 43 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 45 });
    try testing.expectEqual(l.next(), Token{ .kind = .rparen, .start_pos = 46 });
    try testing.expectEqual(l.next(), Token{ .kind = .lbracket, .start_pos = 48 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 52 });
    try testing.expectEqual(l.next(), Token{ .kind = .plus, .start_pos = 54 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 56 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 57 });
    try testing.expectEqual(l.next(), Token{ .kind = .rbracket, .start_pos = 59 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 60 });
    try testing.expectEqual(l.next(), Token{ .kind = .let, .start_pos = 63, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 67, .len = 6 });
    try testing.expectEqual(l.next(), Token{ .kind = .assign, .start_pos = 74 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 76, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .lparen, .start_pos = 79 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 80, .len = 4 });
    try testing.expectEqual(l.next(), Token{ .kind = .comma, .start_pos = 84 });
    try testing.expectEqual(l.next(), Token{ .kind = .ident, .start_pos = 86, .len = 3 });
    try testing.expectEqual(l.next(), Token{ .kind = .rparen, .start_pos = 89 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 90 });
    try testing.expectEqual(l.next(), Token{ .kind = .bang, .start_pos = 92 });
    try testing.expectEqual(l.next(), Token{ .kind = .minus, .start_pos = 93 });
    try testing.expectEqual(l.next(), Token{ .kind = .slash, .start_pos = 94 });
    try testing.expectEqual(l.next(), Token{ .kind = .star, .start_pos = 95 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 96 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 97 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 99 });
    try testing.expectEqual(l.next(), Token{ .kind = .lt, .start_pos = 101 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 103, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .gt, .start_pos = 106 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 108 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 109 });
    try testing.expectEqual(l.next(), Token{ .kind = .@"if", .start_pos = 112, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .lparen, .start_pos = 115 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 116 });
    try testing.expectEqual(l.next(), Token{ .kind = .lt, .start_pos = 118 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 120, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .rparen, .start_pos = 122 });
    try testing.expectEqual(l.next(), Token{ .kind = .lbracket, .start_pos = 124 });
    try testing.expectEqual(l.next(), Token{ .kind = .@"return", .start_pos = 128, .len = 6 });
    try testing.expectEqual(l.next(), Token{ .kind = .@"true", .start_pos = 135, .len = 4 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 139 });
    try testing.expectEqual(l.next(), Token{ .kind = .rbracket, .start_pos = 141 });
    try testing.expectEqual(l.next(), Token{ .kind = .@"else", .start_pos = 143, .len = 4 });
    try testing.expectEqual(l.next(), Token{ .kind = .lbracket, .start_pos = 148 });
    try testing.expectEqual(l.next(), Token{ .kind = .@"return", .start_pos = 152, .len = 6 });
    try testing.expectEqual(l.next(), Token{ .kind = .@"false", .start_pos = 159, .len = 5 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 164 });
    try testing.expectEqual(l.next(), Token{ .kind = .rbracket, .start_pos = 166 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 169, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .eq, .start_pos = 172, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 175, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 177 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 179, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .neq, .start_pos = 182, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 185 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 186 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 188 });
    try testing.expectEqual(l.next(), Token{ .kind = .le, .start_pos = 190, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 193, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 195 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 197, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .ge, .start_pos = 200, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .int, .start_pos = 203, .len = 2 });
    try testing.expectEqual(l.next(), Token{ .kind = .semicolon, .start_pos = 205 });
}
