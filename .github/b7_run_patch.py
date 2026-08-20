from pathlib import Path

patch_source = Path('.github/b7_apply_patch.py').read_text(encoding='utf-8')
marker = 'workflow = ".github/workflows/mumps-direct-ci.yml"'
if marker not in patch_source:
    raise RuntimeError('B7 patch script workflow marker bulunamadi.')

# Kaynak/test/CMake patch bölümü marker öncesinde tamamen assert kontrollüdür.
# Workflow dosyası GitHub connector ile ayrı committe güncellenecek; Actions token
# workflow dosyası yazma yetkisine bağımlı bırakılmayacaktır.
source_patch = patch_source.split(marker, 1)[0]
exec(compile(source_patch, '.github/b7_apply_patch.py', 'exec'), {})

print('B7 AUTO policy source/test patch başarıyla uygulandı.')
