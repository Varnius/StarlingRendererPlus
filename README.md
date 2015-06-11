Starling Renderer Plus
====================

Deferred shading and post-fx extension for Starling
------------------------------------------------------------

This project is intended to remove the need to have <a href="https://github.com/Varnius/Starling-Framework">separate Starling fork</a> for my Starling deferred renderer extension, thus making it a standalone extension which should work with official releases of Starling.

Though, for the time being, some code is left within the fork, so you should include both this library and the fork.
Check [nekobit.eu](http://www.nekobit.eu) for more info.

Library contents:
-----------------

* Deferred renderer which supports
 * Ambient and point lights
 * Spotlights
* Pixel-perfect 2D shadow renderer
* Post FX renderer, currently contains following effects:
 * Bloom
 * Anamorphic Flares
 
<b>Note: using filters/stencil masks on elements inside DeferredShadingContainer (or container itself) is currently not supported.</b> 

<b>Note 2: you may get "Native shader compilation error" while using STANDARD_EXTENDED. Probably the bug of Flash runtime.</b> 
 
<a href="http://nekobit.eu/demos/starling-deferred/Sandbox.html" target="_blank">Online Demo</a> (project can be found [here](https://github.com/Varnius/StarlingDynamicShadows2D))

<a href="http://nekobit.eu/demos/starling-deferred/Sandbox.html" target="_blank"><img src="http://nekobit.eu/screens/deferred.jpg" alt="" /></a>

Deferred renderer is partially based on blog posts [here](http://www.catalinzima.com/xna/tutorials/deferred-rendering-in-xna/) and [here](http://www.soolstyle.com/2010/06/29/2d-lightning-continued/).
