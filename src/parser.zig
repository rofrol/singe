const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const lexer = @import("lexer.zig");
const Token = lexer.Token;
const Pos = lexer.Pos;
const Lexer = lexer.Lexer;

const Ident = struct {
    pos: Pos,
    fn string(i: Ident, input: []const u8) []const u8 {
        return i.pos.string(input);
    }
};

const Statement = struct {
    token: Token,
    ident: Ident,
    value: Expr,
};

const Expr = union {
    value: Token,
    functon: []Statement,
};

const ErrorQueue = struct {
    alloc: mem.Allocator,

    errors: ArrayList([]const u8),

    const Self = @This();
    pub fn init(alloc: mem.Allocator) ErrorQueue {
        return ErrorQueue{
            .alloc = alloc,
            .errors = ArrayList([]const u8).init(alloc),
        };
    }

    pub fn print(self: *Self, comptime format: []const u8, args: anytype) void {
        const err = fmt.allocPrint(self.alloc, format, args) catch return;
        self.errors.append(err) catch {};
    }

    pub fn deinit(self: *Self) void {
        for (self.errors.items) |err| {
            self.alloc.free(err);
        }
        self.errors.deinit();
    }
};

const Parser = struct {
    lex: Lexer,
    err: ErrorQueue,

    const Self = @This();
    pub fn init(alloc: mem.Allocator, input: []const u8) Parser {
        return Self{
            .lex = Lexer.init(input),
            .err = ErrorQueue.init(alloc),
        };
    }

    pub fn deinit(s: *Self) void {
        s.err.deinit();
    }

    pub fn writeErr(s: *Self, writer: anytype) void {
        for (s.err.errors.items) |err| {
            writer.writeAll(err) catch {};
            writer.writeAll("\n") catch {};
        }
    }

    pub fn next(s: *Self) ?Statement {
        const tok = s.lex.next();
        switch (tok) {
            .let => return s.parseLet(tok.let),
            else => s.err.print("expected 'let' but got '{s}' at {s}", .{ tok, tok.pos().string(s.lex.input) }),
        }
        return null;
    }

    fn parseLet(s: *Self, let: Pos) ?Statement {
        const ident = s.lex.next();
        if (!s.expectAnyTok(&.{Token.parse("a")}, ident)) return null;

        const assign = s.lex.next();
        if (!s.expectAnyTok(&.{Token.parse("=")}, assign)) return null;

        const value = s.lex.next();
        if (!(s.expectAnyTok(&.{ Token.parse("0"), Token.parse("\"\"") }, value))) return null;

        const semco = s.lex.next();
        if (!s.expectAnyTok(&.{Token.parse(";")}, semco)) return null;

        return Statement{
            .token = .{ .let = let },
            .ident = Ident{ .pos = ident.pos() },
            .value = Expr{ .value = value },
        };
    }

    fn expectAnyTok(self: *Self, expect: []const Token, got: Token) bool {
        for (expect) |e| if (@enumToInt(got) == @enumToInt(e)) return true;

        self.err.print("expected '{s}' but got '{s}' at {s}", .{ expect, got, got.pos().string(self.lex.input) });
        return false;
    }
};

test "let assign value" {
    const input = "let a = \"hello world\";";
    var p = Parser.init(testing.allocator, input);
    defer p.deinit();
    if (p.next()) |node| {
        try testing.expectEqualStrings(node.token.pos().string(input), "let");
        try testing.expectEqualStrings(node.ident.pos.string(input), "a");
        try testing.expectEqualStrings(node.value.value.pos().string(input), "\"hello world\"");
    }

    if (p.err.errors.items.len != 0) {
        var out = ArrayList(u8).init(testing.allocator);
        defer out.deinit();
        p.writeErr(out.writer());
        try testing.expectEqualStrings(out.items, "");
    }
}

test "no semicolon" {
    const input = "let a = 12";
    var p = Parser.init(testing.allocator, input);
    defer p.deinit();
    if (p.next()) |node| {
        try testing.expectEqualStrings(node.token.pos().string(input), "let");
        try testing.expectEqualStrings(node.ident.pos.string(input), "a");
        try testing.expectEqualStrings(node.value.value.pos().string(input), "12");
    }

    if (p.err.errors.items.len < 1) std.log.err("expected an error but got {}", .{p.err.errors.items.len});
}
