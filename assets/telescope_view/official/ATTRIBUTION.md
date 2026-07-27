# Optical Observation Media Attribution

Downloaded: 2026-07-25

These runtime PNGs are locally packaged RGBA derivatives, reduced to
1024 x 1024. Isolated planets retain the complete disk or ring system on a
truly transparent canvas with a safe margin. Lunar surface targets remain
sharp opaque overscan masters. Deep-sky targets use structure-derived alpha:
transparent pixels follow measured sky background, while actual stars,
galaxy arms, dust lanes, and nebular emission remain. This is not a
rectangular edge feather. Godot applies the one fixed radial eyepiece mask at
runtime. Focus, seeing, drift, clouds, magnification, and sky brightness are
applied by Godot at runtime. No image is hot-linked.

NASA media is used under the [NASA Media Usage Guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/).
NASA, ESA, ESO, NOIRLab, NSF, AURA, and contributing authors do not endorse
Pixel Observatory.

ESO media is used under [ESO's CC BY 4.0 media policy](https://www.eso.org/public/outreach/copyright/).
NOIRLab media is credited according to the source page.

| Runtime file | Source page / credit | License | Processing |
|---|---|---|---|
| `mercury.png` | [Mercury in color](https://commons.wikimedia.org/wiki/File:Mercury_in_color_-_Prockter07_centered.jpg), NASA/JHUAPL/Carnegie | Public domain | Complete disk on transparent RGBA canvas; contain-fit with safe margin |
| `venus.png` | [Venus real color](https://commons.wikimedia.org/wiki/File:Venus-real_color.jpg), NASA/JPL | Public domain | Official cloud disk with a derived crescent mask on transparent RGBA canvas |
| `saturn.png` | [Saturn from Cassini](https://commons.wikimedia.org/wiki/File:Saturn_from_Cassini_Orbiter_(2004-10-06).jpg), NASA/JPL/Space Science Institute | Public domain | Full disk and ring system isolated on transparent RGBA canvas |
| `uranus.png` | [Uranus - Voyager 2](https://commons.wikimedia.org/wiki/File:Uranus_-_Voyager_2.jpg), NASA | Public domain | Full circular disk recovered with square source crop and transparent safe margin |
| `neptune.png` | [Neptune Full](https://commons.wikimedia.org/wiki/File:Neptune_Full.jpg), NASA | Public domain | Complete disk on transparent RGBA canvas; contain-fit with safe margin |
| `moon_crater_copernicus.png` | [Copernicus (LRO)](https://commons.wikimedia.org/wiki/File:Copernicus_(LRO).png), NASA/LRO | Public domain | Square field crop, monochrome night tone |
| `moon_mare_tranquillitatis.png` | [Mare Tranquillitatis (LRO)](https://commons.wikimedia.org/wiki/File:Mare_Tranquillitatis_(LRO).png), NASA/LRO | Public domain | Square field crop, monochrome night tone |
| `moon_terminator.png` | [Lunar Terminator (LROC1126)](https://commons.wikimedia.org/wiki/File:Lunar_Terminator_(LROC1126_-_content_M1321388053_LRmos_warp_str01_square_crop_1100pix).png), NASA/GSFC/ASU | Public domain | Existing square crop, monochrome night tone |
| `albireo.png` | [Albireo double star](https://commons.wikimedia.org/wiki/File:Albireo_double_star.jpg), N. B. / Brucyn | CC BY-SA 4.0 | Square crop, restrained blue-gold color; derivative remains CC BY-SA 4.0 |
| `pleiades.png` | [The Pleiades](https://www.eso.org/public/images/b11/), ESO/S. Brunier | CC BY 4.0 | Target-centered cover crop; nebulosity reduced for an eyepiece view; no baked edge mask |
| `m13.png` | [Hubble image of M13](https://commons.wikimedia.org/wiki/File:Hubble_image_of_globular_cluster_M13_(opo0840a).jpg), NASA/ESA/Hubble Heritage Team | Public domain | Target-centered cover crop; brightness and saturation reduced; no baked edge mask |
| `ring_nebula.png` | [M57, NGC 6720](https://noirlab.edu/public/images/noao-m57/), N. A. Sharp/REU/NOIRLab/NSF/AURA | CC BY 4.0 | Cover crop retaining the ring and surrounding field; no baked edge mask |
| `lagoon_nebula.png` | [The glow of the Lagoon Nebula](https://www.eso.org/public/images/potw1016a/), ESO/IDA/Danish 1.5 m/R. Gendler/U. G. Jorgensen/K. Harpsoe | CC BY 4.0 | Target-centered cover crop; long-exposure color restrained; no baked edge mask |
| `sombrero_galaxy.png` | [The Sombrero Galaxy](https://www.eso.org/public/images/sombrero/), ESO/IDA/Danish 1.5 m/R. Gendler/J.-E. Ovaldsen | CC BY 4.0 | Cover crop centered at `(0.50, 0.52)`; lifted warm nucleus, local contrast and dust lane; no baked edge mask |
| `crab_nebula.png` | [Wide view of the Crab Nebula](https://www.eso.org/public/images/potw1523a/), ESO/Manu Mejias | CC BY 4.0 | Target-centered cover crop retaining filaments; lower saturation; no baked edge mask |
| `dumbbell_nebula.png` | [The Dumbbell Nebula](https://www.eso.org/public/images/eso9846a/), ESO/I. Appenzeller/W. Seifert/O. Stahl/M. Zamani | CC BY 4.0 | Target-centered cover crop preserving the shell; no baked edge mask |
| `double_cluster.png` | [The Double Cluster in Perseus](https://www.eso.org/public/images/b02/), ESO/S. Brunier | CC BY 4.0 | Cover crop preserving both cluster centers; no baked edge mask |
| `whirlpool_galaxy.png` | [Out of This Whirl: M51 and Companion](https://science.nasa.gov/asset/hubble/out-of-this-whirl-the-whirlpool-galaxy-m51-and-companion-galaxy/), NASA/ESA/S. Beckwith/STScI/Hubble Heritage Team | NASA media guidelines | Full M51/NGC 5195 pair retained; restrained ground-optical tone; structure-derived alpha, no baked edge mask |
| `needle_galaxy.png` | [Spiral galaxy NGC 4565](https://www.eso.org/public/images/eso0525a/), ESO | CC BY 4.0 | Target-centered cover crop preserving edge-on disk, bulge and dust lane; no baked edge mask |

## Existing Project Masters

The pre-existing Moon, Mars, Jupiter, Orion Nebula, Andromeda, and point-source
star masters remain in use. Their original provenance was not documented in
the repository before this pass. They are intentionally listed separately
instead of being assigned an unverified external license. A future provenance
pass should either document their original creation/source or replace them
with the already researched NASA/ESO candidates.
