Starling Renderer Plus
====================

Starling deferred shading and post-fx extension for Starling
------------------------------------------------------------

This project is intended to remove the need to have separate Starling fork for my <a href="https://github.com/Varnius/Starling-Framework">Starling deferred renderer</a> extension, thus making it a standalone extension which should work with official releases of Starling.

For the time being, some code is left within the fork, so you should include both this library and the fork.

Library contents:
-----------------

* Deferred renderer which supports
 * Ambient and point lights.
 * Spotlights (TODO)
* Pixel-perfect 2D shadow renderer
* Post FX renderer, currently contains following effects:
 * Bloom
 * Anamorphic Flares
 
<a href="http://nekobit.eu/demos/starling-deferred/Sandbox.html" target="_blank">Online Demo</a> (project can be found [here](https://github.com/Varnius/StarlingDynamicShadows2D))

<a href="http://nekobit.eu/demos/starling-deferred/Sandbox.html" target="_blank"><img src="http://nekobit.eu/screens/mrt.png" alt="" /></a>
