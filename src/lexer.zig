const std = @import("std");
const testing = std.testing;
const mem = std.mem;

pub const Pos = struct {
    start: usize,
    end: usize,

    pub fn z() Pos {
        return Pos.new(0, 0);
    }

    pub fn new(start: usize, end: usize) Pos {
        return Pos{ .start = start, .end = end };
    }

    pub fn string(p: Pos, input: []const u8) []const u8 {
        return input[p.start..p.end];
    }

    pub fn len(p: Pos) usize {
        return p.end - p.start;
    }
};

pub const Token = union(enum) {
    illegal: Pos,
    eof: Pos,

    // Identifiers & literals
    ident: Pos,
    int: Pos,
    string: Pos, // contains the string delims

    // op
    assign: Pos,
    plus: Pos,
    minus: Pos,
    eq: Pos,
    neq: Pos,
    lt: Pos,
    gt: Pos,
    ge: Pos,
    le: Pos,
    slash: Pos,
    star: Pos,
    bang: Pos,

    // Delimiters
    lparen: Pos,
    rparen: Pos,
    lbrace: Pos,
    rbrace: Pos,
    lbracket: Pos,
    rbracket: Pos,
    semicolon: Pos,
    comma: Pos,
    dot: Pos,
    colon: Pos,

    // Keywords
    func: Pos,
    let: Pos,
    @"if": Pos,
    @"else": Pos,
    @"return": Pos,
    @"true": Pos,
    @"false": Pos,
    @"nil": Pos,
    @"for": Pos,

    pub fn pos(t: Token) Pos {
        switch (t) {
            .illegal => return t.illegal,
            .eof => return t.eof,
            .ident => return t.ident,
            .int => return t.int,
            .string => return t.string,
            .assign => return t.assign,
            .plus => return t.plus,
            .minus => return t.minus,
            .eq => return t.eq,
            .neq => return t.neq,
            .lt => return t.lt,
            .gt => return t.gt,
            .ge => return t.ge,
            .le => return t.le,
            .slash => return t.slash,
            .star => return t.star,
            .bang => return t.bang,
            .lparen => return t.lparen,
            .rparen => return t.rparen,
            .lbrace => return t.lbrace,
            .rbrace => return t.rbrace,
            .lbracket => return t.lbracket,
            .rbracket => return t.rbracket,
            .semicolon => return t.semicolon,
            .comma => return t.comma,
            .dot => return t.dot,
            .colon => return t.colon,
            .func => return t.func,
            .let => return t.let,
            .@"if" => return t.@"if",
            .@"else" => return t.@"else",
            .@"return" => return t.@"return",
            .@"true" => return t.@"true",
            .@"false" => return t.@"false",
            .@"nil" => return t.@"nil",
            .@"for" => return t.@"for",
        }
    }

    /// like parsePos, but starts at offset 0
    pub fn parse(input: []const u8) Token {
        return Token.parsePos(input, 0);
    }

    /// parse the next token from offset
    pub fn parsePos(input: []const u8, offset: usize) Token {
        if (offset > input.len) return Token{ .eof = Pos.new(offset, offset) };
        if (switch (input[offset]) {
            '(' => Token{ .lparen = Pos.new(offset, offset + 1) },
            ')' => Token{ .rparen = Pos.new(offset, offset + 1) },
            '{' => Token{ .lbracket = Pos.new(offset, offset + 1) },
            '}' => Token{ .rbracket = Pos.new(offset, offset + 1) },
            '[' => Token{ .lbrace = Pos.new(offset, offset + 1) },
            ']' => Token{ .rbrace = Pos.new(offset, offset + 1) },
            ';' => Token{ .semicolon = Pos.new(offset, offset + 1) },
            ',' => Token{ .comma = Pos.new(offset, offset + 1) },
            '.' => Token{ .dot = Pos.new(offset, offset + 1) },
            ':' => Token{ .colon = Pos.new(offset, offset + 1) },
            '+' => Token{ .plus = Pos.new(offset, offset + 1) },
            '=' => if (offset + 1 < input.len and input[offset + 1] == '=')
                return Token{ .eq = Pos.new(offset, offset + 2) }
            else
                Token{ .assign = Pos.new(offset, offset + 1) },
            '-' => Token{ .minus = Pos.new(offset, offset + 1) },
            '<' => if (offset + 1 < input.len and input[offset + 1] == '=')
                return Token{ .le = Pos.new(offset, offset + 2) }
            else
                Token{ .lt = Pos.new(offset, offset + 1) },
            '>' => if (offset + 1 < input.len and input[offset + 1] == '=')
                return Token{ .ge = Pos.new(offset, offset + 2) }
            else
                Token{ .gt = Pos.new(offset, offset + 1) },
            '*' => Token{ .star = Pos.new(offset, offset + 1) },
            '/' => Token{ .slash = Pos.new(offset, offset + 1) },
            '!' => if (offset + 1 < input.len and input[offset + 1] == '=')
                Token{ .neq = Pos.new(offset, offset + 2) }
            else
                Token{ .bang = Pos.new(offset, offset + 1) },
            '"' => {
                const start = offset + 1;

                var end = start;
                while (end < input.len and (input[end] != '"' or input[end - 1] == '\\')) : (end += 1) {}

                if (end == input.len) return Token{ .illegal = Pos.new(offset, end + 1) };
                return Token{ .string = Pos.new(offset, end + 1) };
            },
            else => null,
        }) |tok| return tok;

        const t = if (mem.tokenize(u8, input[offset..], " \t\n\r;(){}[],.:+=").next()) |n| n else return Token{ .eof = Pos.new(offset, offset) };
        return if (mem.eql(u8, t, "let"))
            Token{ .let = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "fn"))
            Token{ .func = Pos.new(offset, offset + t.len) }
        else if (containsOnlyAnyOf(u8, t, "0123456789"))
            Token{ .int = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "<="))
            Token{ .le = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, ">="))
            Token{ .ge = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "=="))
            Token{ .eq = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "!="))
            Token{ .neq = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "true"))
            Token{ .@"true" = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "false"))
            Token{ .@"false" = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "nil"))
            Token{ .@"nil" = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "if"))
            Token{ .@"if" = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "else"))
            Token{ .@"else" = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "return"))
            Token{ .@"return" = Pos.new(offset, offset + t.len) }
        else if (mem.eql(u8, t, "for"))
            Token{ .@"for" = Pos.new(offset, offset + t.len) }
        else
            Token{ .ident = Pos.new(offset, offset + t.len) };
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
    offset: usize = 0,

    const Self = @This();
    pub fn init(input: []const u8) Self {
        return Self{ .input = input };
    }

    pub fn next(self: *Self) Token {
        while (self.offset < self.input.len) {
            self.eatWhileAnyOf(" \t\r\n");
            const t = Token.parsePos(self.input, self.offset);
            self.offset += t.pos().len();
            return t;
        }

        return Token{ .eof = Pos.new(self.offset, self.offset) };
    }

    fn eatWhileAnyOf(self: *Self, needle_stack: []const u8) void {
        while (self.offset + 1 < self.input.len) : (self.offset += 1) {
            if (!containsOnlyAnyOf(u8, self.input[self.offset .. self.offset + 1], needle_stack)) break;
        }
    }
};

test "empty" {
    var l = Lexer.init("");
    try testing.expect(l.next() == .eof);
}

test ";;;" {
    var l = Lexer.init(";;;");
    try testing.expect(l.next() == .semicolon);
    try testing.expect(l.next() == .semicolon);
    try testing.expect(l.next() == .semicolon);
    try testing.expect(l.next() == .eof);
}

test "let" {
    var l = Lexer.init("let");
    try testing.expectEqual(l.next(), Token{ .let = Pos.new(0, 3) });
    try testing.expectEqual(l.next(), Token{ .eof = Pos.new(3, 3) });
}

test "let expr" {
    var l = Lexer.init("let a = 27;");
    try testing.expectEqual(l.next(), Token{ .let = Pos.new(0, 3) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(4, 5) });
    try testing.expectEqual(l.next(), Token{ .assign = Pos.new(6, 7) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(8, 10) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(10, 11) });
    try testing.expectEqual(l.next(), Token{ .eof = Pos.new(11, 11) });
}

test "let string" {
    var l = Lexer.init(
        \\let hello_world = "hello world";
    );
    try testing.expectEqual(l.next(), Token{ .let = Pos.new(0, 3) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(4, 15) });
    try testing.expectEqual(l.next(), Token{ .assign = Pos.new(16, 17) });
    const hello_world = l.next();
    try testing.expectEqual(hello_world, Token{ .string = Pos.new(18, 31) });
    try testing.expectEqualStrings(hello_world.string.string(l.input), "\"hello world\"");
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(31, 32) });
}

test "escaped string" {
    var l = Lexer.init(
        \\"\"hello world\""
    );
    const hello_world = l.next();
    try testing.expectEqual(hello_world, Token{ .string = Pos.new(0, 17) });
    try testing.expectEqualStrings(hello_world.string.string(l.input),
        \\"\"hello world\""
    );
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
    try testing.expectEqual(l.next(), Token{ .let = Pos.new(0, 3) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(4, 8) });
    try testing.expectEqual(l.next(), Token{ .assign = Pos.new(9, 10) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(11, 12) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(12, 13) });
    try testing.expectEqual(l.next(), Token{ .let = Pos.new(14, 17) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(18, 21) });
    try testing.expectEqual(l.next(), Token{ .assign = Pos.new(22, 23) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(24, 26) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(26, 27) });
    try testing.expectEqual(l.next(), Token{ .let = Pos.new(29, 32) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(33, 36) });
    try testing.expectEqual(l.next(), Token{ .assign = Pos.new(37, 38) });
    try testing.expectEqual(l.next(), Token{ .func = Pos.new(39, 41) });
    try testing.expectEqual(l.next(), Token{ .lparen = Pos.new(41, 42) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(42, 43) });
    try testing.expectEqual(l.next(), Token{ .comma = Pos.new(43, 44) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(45, 46) });
    try testing.expectEqual(l.next(), Token{ .rparen = Pos.new(46, 47) });
    try testing.expectEqual(l.next(), Token{ .lbracket = Pos.new(48, 49) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(52, 53) });
    try testing.expectEqual(l.next(), Token{ .plus = Pos.new(54, 55) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(56, 57) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(57, 58) });
    try testing.expectEqual(l.next(), Token{ .rbracket = Pos.new(59, 60) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(60, 61) });
    try testing.expectEqual(l.next(), Token{ .let = Pos.new(63, 66) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(67, 73) });
    try testing.expectEqual(l.next(), Token{ .assign = Pos.new(74, 75) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(76, 79) });
    try testing.expectEqual(l.next(), Token{ .lparen = Pos.new(79, 80) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(80, 84) });
    try testing.expectEqual(l.next(), Token{ .comma = Pos.new(84, 85) });
    try testing.expectEqual(l.next(), Token{ .ident = Pos.new(86, 89) });
    try testing.expectEqual(l.next(), Token{ .rparen = Pos.new(89, 90) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(90, 91) });
    try testing.expectEqual(l.next(), Token{ .bang = Pos.new(92, 93) });
    try testing.expectEqual(l.next(), Token{ .minus = Pos.new(93, 94) });
    try testing.expectEqual(l.next(), Token{ .slash = Pos.new(94, 95) });
    try testing.expectEqual(l.next(), Token{ .star = Pos.new(95, 96) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(96, 97) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(97, 98) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(99, 100) });
    try testing.expectEqual(l.next(), Token{ .lt = Pos.new(101, 102) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(103, 105) });
    try testing.expectEqual(l.next(), Token{ .gt = Pos.new(106, 107) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(108, 109) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(109, 110) });
    try testing.expectEqual(l.next(), Token{ .@"if" = Pos.new(112, 114) });
    try testing.expectEqual(l.next(), Token{ .lparen = Pos.new(115, 116) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(116, 117) });
    try testing.expectEqual(l.next(), Token{ .lt = Pos.new(118, 119) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(120, 122) });
    try testing.expectEqual(l.next(), Token{ .rparen = Pos.new(122, 123) });
    try testing.expectEqual(l.next(), Token{ .lbracket = Pos.new(124, 125) });
    try testing.expectEqual(l.next(), Token{ .@"return" = Pos.new(128, 134) });
    try testing.expectEqual(l.next(), Token{ .@"true" = Pos.new(135, 139) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(139, 140) });
    try testing.expectEqual(l.next(), Token{ .rbracket = Pos.new(141, 142) });
    try testing.expectEqual(l.next(), Token{ .@"else" = Pos.new(143, 147) });
    try testing.expectEqual(l.next(), Token{ .lbracket = Pos.new(148, 149) });
    try testing.expectEqual(l.next(), Token{ .@"return" = Pos.new(152, 158) });
    try testing.expectEqual(l.next(), Token{ .@"false" = Pos.new(159, 164) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(164, 165) });
    try testing.expectEqual(l.next(), Token{ .rbracket = Pos.new(166, 167) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(169, 171) });
    try testing.expectEqual(l.next(), Token{ .eq = Pos.new(172, 174) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(175, 177) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(177, 178) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(179, 181) });
    try testing.expectEqual(l.next(), Token{ .neq = Pos.new(182, 184) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(185, 186) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(186, 187) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(188, 189) });
    try testing.expectEqual(l.next(), Token{ .le = Pos.new(190, 192) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(193, 195) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(195, 196) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(197, 199) });
    try testing.expectEqual(l.next(), Token{ .ge = Pos.new(200, 202) });
    try testing.expectEqual(l.next(), Token{ .int = Pos.new(203, 205) });
    try testing.expectEqual(l.next(), Token{ .semicolon = Pos.new(205, 206) });
}