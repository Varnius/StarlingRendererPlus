Starling Renderer Plus
====================

Deferred shading and post-fx extension for Starling
------------------------------------------------------------

A deferred shading extension for Starling 2.

With Starling 1.x, a separate custom Starling fork was required. No longer needed with Starling 2.
Check [nekobit.eu](http://www.nekobit.eu) for more info.

Library contents:
-----------------

* Deferred renderer which supports
 * Ambient, Spot, Point lights
* Pixel-perfect 2D shadow renderer
* Post FX renderer, currently contains following effects:
 * Bloom (port to Starling 2 in progress)
 * Anamorphic Flares (port to Starling 2 in progress)
 
<b>Note: using filters/stencil masks on elements inside DeferredShadingContainer (or container itself) is currently not supported.</b> 

<b>Note 2: you may get "Native shader compilation error" while using STANDARD_EXTENDED. Probably the bug of Flash runtime.</b> 
 
<a href="http://nekobit.eu/demos/starling-deferred/Sandbox.html" target="_blank">Online Demo</a> (project can be found [here](https://github.com/Varnius/StarlingDynamicShadows2D))

<a href="http://nekobit.eu/demos/starling-deferred/Sandbox.html" target="_blank"><img src="http://nekobit.eu/screens/deferred.jpg" alt="" /></a>

Deferred renderer is partially based on blog posts [here](http://www.catalinzima.com/xna/tutorials/deferred-rendering-in-xna/) and [here](http://www.soolstyle.com/2010/06/29/2d-lightning-continued/).
