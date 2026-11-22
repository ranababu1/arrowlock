"""Checks that an AAB or APK runs on Android devices with 16 KB memory pages.

Usage: python -I tools/check_16kb.py <file.aab|file.apk> [...]

Google Play requires this for apps that target Android 15 (API 35) or newer.
For every native library (lib/<abi>/*.so, or base/lib/<abi>/*.so in an AAB):
  - every LOAD segment of the ELF file must be aligned to at least 16 KB;
  - in an APK, a library stored uncompressed must start at a 16 KB offset in
    the zip (Android maps it straight from the APK). Compressed libraries are
    extracted at install, so their zip offset does not matter. An AAB is
    re-packed by Play, so only the ELF alignment is checked there.
Only 64-bit ABIs (arm64-v8a, x86_64) are checked: 16 KB pages exist only there.
Standard library only. Exits 1 and lists each problem when a check fails.
"""
import struct
import sys
import zipfile

PAGE = 16384
ABIS_64 = ("arm64-v8a", "x86_64")
PT_LOAD = 1


def elf_problems(name, data):
	"""Problems with the LOAD segment alignment of one ELF file."""
	if data[:4] != b"\x7fELF":
		return [f"{name}: not an ELF file"]
	if data[4] != 2:
		return [f"{name}: not a 64-bit ELF file"]
	end = "<" if data[5] == 1 else ">"
	phoff, = struct.unpack_from(end + "Q", data, 0x20)
	phentsize, phnum = struct.unpack_from(end + "HH", data, 0x36)
	problems = []
	loads = 0
	for i in range(phnum):
		off = phoff + i * phentsize
		p_type, = struct.unpack_from(end + "I", data, off)
		if p_type != PT_LOAD:
			continue
		loads += 1
		p_align, = struct.unpack_from(end + "Q", data, off + 0x30)
		if p_align < PAGE:
			problems.append(f"{name}: LOAD segment {i} aligned to {p_align} bytes, needs {PAGE}")
	if loads == 0:
		problems.append(f"{name}: no LOAD segments")
	return problems


def data_offset(z, info):
	"""Offset of the entry's data in the zip (after its local header)."""
	z.fp.seek(info.header_offset)
	header = z.fp.read(30)
	name_len, extra_len = struct.unpack_from("<HH", header, 26)
	return info.header_offset + 30 + name_len + extra_len


def check(path):
	"""(problems, number of libraries checked) for one AAB or APK."""
	problems = []
	checked = 0
	is_bundle = path.lower().endswith(".aab")
	with zipfile.ZipFile(path) as z:
		for info in z.infolist():
			parts = info.filename.split("/")
			if is_bundle and parts[0] == "base":
				parts = parts[1:]
			if len(parts) != 3 or parts[0] != "lib" or parts[1] not in ABIS_64 or not parts[2].endswith(".so"):
				continue
			checked += 1
			problems += elf_problems(info.filename, z.read(info))
			if not is_bundle and info.compress_type == zipfile.ZIP_STORED:
				offset = data_offset(z, info)
				if offset % PAGE != 0:
					problems.append(f"{info.filename}: stored uncompressed at offset {offset}, not 16 KB aligned (zipalign -P 16)")
	if checked == 0:
		problems.append("no 64-bit native libraries found")
	return problems, checked


def main(paths):
	failed = False
	for path in paths:
		problems, checked = check(path)
		if problems:
			failed = True
			print(f"  {path}: NOT 16 KB compatible")
			for p in problems:
				print(f"    {p}")
		else:
			print(f"  {path}: 16 KB compatible ({checked} native libraries)")
	return 1 if failed else 0


if __name__ == "__main__":
	if len(sys.argv) < 2:
		print(__doc__.strip())
		sys.exit(2)
	sys.exit(main(sys.argv[1:]))
