import os
import re

directory = r'c:\Users\yacob\Documents\dymwa\lib'
pattern = re.compile(r'\.withOpacity\((.*?)\)')
replacement = r'.withValues(alpha: \1)'

changed_files = 0
for root, dirs, files in os.walk(directory):
    for filename in files:
        if filename.endswith('.dart'):
            filepath = os.path.join(root, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = pattern.sub(replacement, content)
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                changed_files += 1

print(f"Fixed withOpacity in {changed_files} files.")
