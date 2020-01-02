import sys

def hashes_paths():
    with open(sys.argv[1], 'r') as f:
        for line in f.readlines():
            hash, _, path = line.strip().partition(' ')
            yield hash, path[1:]

hashes_paths = list(hashes_paths())

for hash, path in hashes_paths:
    print(f"extern unsigned char blob_{hash}_start;")
    print(f"extern unsigned char blob_{hash}_end;")
    print(f"extern unsigned char blob_{hash}_size;")

print('typedef struct static_file {')
print('    char *hash;')
print('    // length of hash in bytes, excluding terminating 0 char')
print('    size_t hash_len;')
print('    char *path;')
print('    // length of path in bytes, excluding terminating 0 char')
print('    size_t path_len;')
print('    // file contents, no terminating 0 char')
print('    void *data;')
print('    // size of file contents in bytes')
print('    size_t data_len;')
print('} static_file;')

print('const static static_file static_files[] = {')
for hash, path in hashes_paths:
    assert not '"' in path
    assert not '"' in hash
    print(f'{{ "{hash}", {len(hash)}, "{path}", {len(path)}, ((void *)&blob_{hash}_start), ((size_t)&blob_{hash}_size)}},')
print('};')
print(f'const static size_t static_files_len = {len(hashes_paths)};')
