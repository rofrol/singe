const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const lexer = @import("lexer.zig");
const Token = lexer.Token;
const Pos = lexer.Pos;
const Lexer = lexer.Lexer;

const Statement = struct {
    ident: Token,
    value: Expr,
};

const Expr = union(enum) {
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

    pub fn deinit(self: *Self) void {
        self.err.deinit();
    }

    pub fn writeErr(self: *Self, writer: anytype) void {
        for (self.err.errors.items) |err| {
            writer.writeAll(err) catch {};
            writer.writeAll("\n") catch {};
        }
    }

    pub fn next(self: *Self) ?Statement {
        const tok = self.lex.next();
        switch (tok.kind) {
            .let => return self.parseLet(),
            else => self.err.print("expected 'let' but got '{s}' at {s}", .{ tok, tok.string(self.lex.input) }),
        }
        return null;
    }

    fn parseLet(self: *Self) ?Statement {
        const ident = self.lex.next();
        if (!self.expectAnyTok(ident, &.{Token.Kind.ident})) return null;

        const assign = self.lex.next();
        if (!self.expectAnyTok(assign, &.{Token.Kind.assign})) return null;

        const value = self.lex.next();
        if (!(self.expectAnyTok(value, &.{ Token.Kind.int, Token.Kind.string }))) return null;

        const semco = self.lex.next();
        if (!self.expectAnyTok(semco, &.{Token.Kind.semicolon})) return null;

        return Statement{ .ident = ident, .value = Expr{ .value = value } };
    }

    fn expectAnyTok(self: *Self, got: Token, want: []const Token.Kind) bool {
        for (want) |w| if (got.kind == w) return true;

        const fp = got.filePos(self.lex.input);
        self.err.print("expected any of '{any}' but got '{T}' at {d}:{d}", .{ want, got.kind, fp.line, fp.col });
        return false;
    }
};

test "let assign value" {
    const input =
        \\let a = "hello world";
    ;
    var p = Parser.init(testing.allocator, input);
    defer p.deinit();
    if (p.next()) |node| {
        try testing.expectEqualStrings(node.ident.string(input), "a");
        try testing.expectEqualStrings(node.value.value.string(input), "\"hello world\"");
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
        try testing.expectEqualStrings(node.ident.string(input), "a");
        try testing.expectEqualStrings(node.value.value.string(input), "12");
    }

    if (p.err.errors.items.len < 1) std.log.err("expected an error but got {}", .{p.err.errors.items.len});
}
