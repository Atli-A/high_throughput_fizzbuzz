const std = @import("std");

pub fn build(b: *std.Build) void {

    const test_step = b.step("test", "Run unit tests");


    const unit_tests = b.addTest(.{
        .root_source_file = b.path("strint.zig"),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);



    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("bcd.zig"),
        .target = b.graph.host,
        .optimize = b.standardOptimizeOption(.{}),
    });
    
    exe.linkLibC();

    b.installArtifact(exe);
}
