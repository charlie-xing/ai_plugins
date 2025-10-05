#!/usr/bin/env python3
"""
Generate macOS app icon for ai_plugins
Creates a modern, minimalist icon using SF Symbols style
"""

import os
import subprocess
import tempfile

# Icon design: Puzzle piece (plugin) + Sparkles (AI) in gradient style
svg_content = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Gradient for modern look -->
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667EEA;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#764BA2;stop-opacity:1" />
    </linearGradient>

    <linearGradient id="iconGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FFFFFF;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#F0F0F0;stop-opacity:0.95" />
    </linearGradient>

    <!-- Shadow filter -->
    <filter id="shadow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="8"/>
      <feOffset dx="0" dy="4" result="offsetblur"/>
      <feComponentTransfer>
        <feFuncA type="linear" slope="0.3"/>
      </feComponentTransfer>
      <feMerge>
        <feMergeNode/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>

  <!-- Rounded square background with gradient -->
  <rect x="0" y="0" width="1024" height="1024" rx="180" ry="180" fill="url(#bgGradient)"/>

  <!-- Main icon group with shadow -->
  <g filter="url(#shadow)">
    <!-- Puzzle piece (plugin symbol) - SF Symbols style -->
    <path d="M 350 280
             L 500 280
             C 500 250 520 230 550 230
             C 580 230 600 250 600 280
             L 750 280
             L 750 430
             C 780 430 800 450 800 480
             C 800 510 780 530 750 530
             L 750 680
             L 600 680
             C 600 710 580 730 550 730
             C 520 730 500 710 500 680
             L 350 680
             L 350 530
             C 320 530 300 510 300 480
             C 300 450 320 430 350 430
             Z"
          fill="url(#iconGradient)"
          stroke="rgba(255,255,255,0.5)"
          stroke-width="4"/>

    <!-- AI Sparkles - top right -->
    <g transform="translate(640, 200)">
      <!-- Large sparkle -->
      <path d="M 0 -30 L 5 -5 L 30 0 L 5 5 L 0 30 L -5 5 L -30 0 L -5 -5 Z"
            fill="rgba(255,255,255,0.95)"
            stroke="rgba(255,255,255,0.6)"
            stroke-width="2"/>
      <!-- Small sparkle -->
      <path d="M 45 15 L 48 20 L 53 23 L 48 26 L 45 31 L 42 26 L 37 23 L 42 20 Z"
            fill="rgba(255,255,255,0.85)"/>
    </g>

    <!-- AI Sparkles - bottom left -->
    <g transform="translate(280, 720)">
      <!-- Medium sparkle -->
      <path d="M 0 -20 L 3 -3 L 20 0 L 3 3 L 0 20 L -3 3 L -20 0 L -3 -3 Z"
            fill="rgba(255,255,255,0.9)"/>
      <!-- Tiny sparkle -->
      <path d="M -35 -25 L -32 -22 L -29 -25 L -32 -28 Z"
            fill="rgba(255,255,255,0.75)"/>
    </g>
  </g>
</svg>'''

def create_icon():
    """Create macOS .icns file from SVG"""

    # Create temporary directory
    with tempfile.TemporaryDirectory() as tmpdir:
        svg_path = os.path.join(tmpdir, 'icon.svg')
        iconset_path = os.path.join(tmpdir, 'AppIcon.iconset')

        # Write SVG file
        with open(svg_path, 'w') as f:
            f.write(svg_content)

        # Create iconset directory
        os.makedirs(iconset_path, exist_ok=True)

        # Icon sizes needed for macOS
        sizes = [
            (16, 'icon_16x16.png'),
            (32, 'icon_16x16@2x.png'),
            (32, 'icon_32x32.png'),
            (64, 'icon_32x32@2x.png'),
            (128, 'icon_128x128.png'),
            (256, 'icon_128x128@2x.png'),
            (256, 'icon_256x256.png'),
            (512, 'icon_256x256@2x.png'),
            (512, 'icon_512x512.png'),
            (1024, 'icon_512x512@2x.png'),
        ]

        print("Generating icon files...")

        # Try using rsvg-convert (if available) or sips
        for size, filename in sizes:
            output_path = os.path.join(iconset_path, filename)

            # Try rsvg-convert first (better quality)
            try:
                subprocess.run([
                    'rsvg-convert',
                    '-w', str(size),
                    '-h', str(size),
                    svg_path,
                    '-o', output_path
                ], check=True, capture_output=True)
                print(f"  ✓ Created {filename}")
            except (subprocess.CalledProcessError, FileNotFoundError):
                # Fall back to using qlmanage + sips (macOS built-in)
                try:
                    # First convert SVG to PNG using qlmanage
                    temp_png = os.path.join(tmpdir, 'temp.png')
                    subprocess.run([
                        'qlmanage',
                        '-t',
                        '-s', str(size),
                        '-o', tmpdir,
                        svg_path
                    ], check=True, capture_output=True)

                    # qlmanage creates icon.svg.png, rename it
                    qlmanage_output = os.path.join(tmpdir, 'icon.svg.png')
                    if os.path.exists(qlmanage_output):
                        os.rename(qlmanage_output, output_path)
                        print(f"  ✓ Created {filename}")
                except:
                    print(f"  ✗ Failed to create {filename}")

        # Create .icns file
        output_icns = 'Sources/ai_plugins/Resources/AppIcon.icns'
        os.makedirs('Sources/ai_plugins/Resources', exist_ok=True)

        print("\nCreating .icns file...")
        try:
            subprocess.run([
                'iconutil',
                '-c', 'icns',
                '-o', output_icns,
                iconset_path
            ], check=True)
            print(f"✓ Successfully created {output_icns}")
            return True
        except subprocess.CalledProcessError as e:
            print(f"✗ Failed to create .icns file: {e}")
            return False

if __name__ == '__main__':
    print("AI Plugins Icon Generator")
    print("=" * 50)
    success = create_icon()
    if success:
        print("\nIcon created successfully!")
        print("The icon will be included in the next build.")
    else:
        print("\nFailed to create icon. Please install librsvg:")
        print("  brew install librsvg")
