/**
 * Created by Derpy on 2016.02.21.
 */
package starling.extensions.deferredShading.lights.rendering
{
    import com.adobe.utils.AGALMiniAssembler;

    import flash.display3D.Context3D;
    import flash.display3D.Context3DBlendFactor;
    import flash.display3D.Context3DProgramType;
    import flash.geom.Point;
    import flash.geom.Rectangle;

    import starling.core.Starling;
    import starling.display.Mesh;
    import starling.extensions.deferredShading.display.DeferredShadingContainer;
    import starling.extensions.deferredShading.lights.Light;
    import starling.extensions.deferredShading.renderer_internal;
    import starling.extensions.utils.ShaderUtils;
    import starling.rendering.MeshEffect;
    import starling.rendering.Program;
    import starling.rendering.VertexDataFormat;

    use namespace renderer_internal;

    public class PointLightEffect extends MeshEffect
    {
        public static const VERTEX_FORMAT:VertexDataFormat = VertexDataFormat.fromString("position:float2");

        // Lightmap

        private var sRenderAlpha:Vector.<Number> = new <Number>[1.0, 1.0, 1.0, 1.0];
        private var constants:Vector.<Number> = new <Number>[0.5, 1.0, 2.0, 0.0];
        private var constants2:Vector.<Number> = new <Number>[3.0, 0.0, 0.0, 0.0];
        private var lightProps:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
        public var lightProps2:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
        private var lightColor:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
        private var halfVec:Vector.<Number> = new <Number>[0.0, 0.0, 1.0, 0.0];
        private var lightPosition:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
        private var attenuationConstants:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
        private static var atan2Constants:Vector.<Number> = new <Number>[
            0.5, 0.5, Math.PI, 2 * Math.PI,
            2.220446049250313e-16, 0.7853981634, 0.1821, 0.9675, // atan2 magic numbers
        ];
        private static var blurConstants:Vector.<Number> = new <Number>[
            0.05, 0.09, 0.12, 0.15,
            1.0, 2.0, 3.0, 4.0,
            0.18, -1.0, 0.0, 0.0
        ];
        private var screenDimensions:Vector.<Number> = new <Number>[0, 0, 0, 0];

        // Shadowmap

        private static var lightBounds:Vector.<Number> = new Vector.<Number>();
        private static var shadowmapConstants:Vector.<Number> = new <Number>[Math.PI, Math.PI * 1.5, 0.0, 0.1];
        private static var shadowmapConstants2:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
        private static var tmpBounds:Rectangle = new Rectangle();

        // Constants

        private static var PIXELS_PER_DRAW_CALL:int;

        public function PointLightEffect()
        {

        }

        override protected function createProgram():Program
        {
            // va0 - position
            // vc0 - mvpMatrix (occupies 4 vectors, vc0 - vc3)

            var vertexProgramCode:String =
                    ShaderUtils.joinProgramArray(
                            [
                                'm44 vt0, va0, vc0',
                                'mov op, vt0',
                                'mov v0, vt0'
                            ]
                    );

            // fc0 - constants [0.5, 1, 2, 0]
            // fc1 - light position in eye coordinates, screen width/height [x, y, z (fake), 0]
            // fc2 - light properties [radius, strength, 1 / radius, radius^2]
            // fc3 - light color [r, g, b, 0]
            // fc4 - halfVec [0, 0, 1, 0]
            // fc5 - attenuation constants [0, 0, 0, att_s]
            // fc7 - [castsShadows, 0, 0, 0]
            // fc8 - [1.0, 0.0, PI, 2PI]
            // fc9 - [1e-10, 0.5PI, 0.0, 0.0]
            // fc10 - constants2 [3, 0, 0, 0]
            // fc11 - blur constants [0.05, 0.09, 0.12, 0.15]
            // fc12 - blur constants [1, 2, 3, 4]
            // fc13 - blur constants [0.16, -1, 0, 0]
            // fc14 - [screenWidth, screenHeight, 0, 0]

//            var fragmentProgramCode:String =
//                    ShaderUtils.joinProgramArray(
//                            [
//                                // Unpack screen coords to [0, 1] by
//                                // multiplying by 0.5 and then adding 0.5
//
//                                'mul ft0.xyxy, v0.xyxy, fc0.xxxx',
//                                'add ft0.xy, ft0.xy, fc0.xx',
//                                'sub ft0.y, fc0.y, ft0.y',
//
//                                // Sample normals to ft1
//
//                                'tex ft1, ft0.xy, fs0 <2d, clamp, linear, mipnone>',
//                                'sub ft1.y, fc0.y, ft1.y ', // y-axis should increase downwards
//
//                                // Then unpack normals from [0, 1] to [-1, 1]
//                                // by multiplying by 2 and then subtracting 1
//
//                                'mul ft1.xyz, ft1.xyz, fc0.zzz',
//                                'sub ft1.xyz, ft1.xyz, fc0.yyy',
//
//                                'nrm ft1.xyz, ft1.xyz',
//
//                                // Sample depth to ft2
//
//                                'tex ft2, ft0.xy, fs1 <2d, clamp, linear, mipnone>',
//
//                                // Put specular power and specular intensity to ft0.zw
//                                // Those are stored in yz of depth
//
//                                'mov ft0.z, ft2.y',
//                                'mov ft0.w, ft2.z',
//
//                                // Calculate pixel position in eye space
//
//                                'mul ft3.xyxy, ft0.xyxy, fc14.xyxy',
//                                'mov ft3.z, fc0.w',
//                                'mov ft21.xyz, ft3.xyz', // save for shadow calculations
//
//                                /*-----------------------
//                                 Calculate coincidence
//                                 between light and surface
//                                 normal
//                                 -----------------------*/
//
//                                // float3 lightDirection3D = lightPosition.xyz - pixelPosition.xyz;
//                                // z(light) = positive float, z(pixel) = 0
//                                'sub ft3.xyz, fc1.xyz, ft3.xyz',
//                                'mov ft3.w, fc0.w',
//
//                                // Save length(lightDirection2D) to ft20.x for later shadow calculations
//                                'pow ft20.x, ft3.x, fc0.z',
//                                'pow ft20.y, ft3.y, fc0.z',
//                                'add ft20.x, ft20.x, ft20.y',
//                                'sqt ft20.x, ft20.x',
//                                'div ft20.x, ft20.x, fc2.x',
//
//                                // float3 lightDirNorm = normalize(lightDirection3D);
//                                'nrm ft7.xyz, ft3.xyz',
//
//                                // float amount = max(dot(normal, lightDirNorm), 0);
//                                // Put it in ft5.x
//                                'dp3 ft5.x, ft1.xyz, ft7.xyz',
//                                'max ft5.x, ft5.x, fc0.w',
//
//                                /*-----------------------
//                                 Calculate attenuation
//                                 -----------------------*/
//
//                                // Linear attenuation
//                                // http://blog.slindev.com/2011/01/10/natural-light-attenuation/
//                                // Put it in ft5.y
//                                'mov ft3.z, fc0.w', // attenuation is calculated in 2D
//                                'dp3 ft5.y, ft3.xyz, ft3.xyz',
//                                'div ft5.y, ft5.y, fc2.w',
//                                'mul ft5.y, ft5.y, fc5.x',
//                                'add ft5.y, ft5.y, fc0.y',
//                                'rcp ft5.y, ft5.y',
//                                'sub ft5.y, ft5.y, fc5.y',
//                                'div ft5.y, ft5.y, fc5.z',
//
//                                /*-----------------------
//                                 Calculate specular
//                                 -----------------------*/
//
//                                'neg ft7.xyz, ft7.xyz',
//                                'dp3 ft6.x, ft7.xyz, ft1.xyz',
//                                'mul ft6.xyz, ft6.xxx, fc0.z',
//                                'mul ft6.xyz, ft6.xxx, ft1.xyz',
//                                'sub ft6.xyz, ft7.xyz, ft6.xyz',
//
//                                'dp3 ft6.x, ft6.xyz, fc4.xyz',
//                                'max ft6.x, ft6.x, fc0.w',
//                                'pow ft5.z, ft6.x, ft0.z',
//
//                                /*-----------------------
//                                 Finalize
//                                 -----------------------*/
//
//                                // Output.Color = lightColor * coneAttenuation * lightStrength
//                                'mul ft6.xyz, ft5.yyy, fc3.xyz',
//                                'mul ft6.xyz, ft6.xyz, ft5.x',
//
//                                // + (coneAttenuation * specular * specularStrength)
//                                'mul ft7.x, ft5.y, ft5.z',
//                                'mul ft7.x, ft7.x, ft0.w',
//                                'mov ft6.w, ft7.x',
//
//                                '<shadows>',
//
//                                // Multiply diffuse color by calculated light amounts
//
//                                'tex ft1, ft0.xy, fs4 <2d, clamp, linear, mipnone>',
//
//                                // light = (specular * lightColor + diffuseLight) * lightStrength
//                                'mul ft2.xyz, ft6.www, fc3.xyz,',
//                                'add ft2.xyz, ft2.xyz, ft6.xyz',
//                                'mul ft2.xyz, ft2.xyz, fc2.yyy ',
//                                'mov ft2.w, fc0.y',
//
//                                // light * diffuseRT
//                                'mul ft2.xyz, ft2.xyz, ft1.xyz',
//                                'mov oc, ft2',
//                            ]
//                    );

            var fragmentProgramCode:String =
                    ShaderUtils.joinProgramArray(
                            [
                                // Unpack screen coords to [0, 1] by
                                // multiplying by 0.5 and then adding 0.5

                                'mul ft0.xyxy, v0.xyxy, fc0.xxxx',
                                'add ft0.xy, ft0.xy, fc0.xx',
                                'sub ft0.y, fc0.y, ft0.y',

                                // Sample normals to ft1

                                'tex ft1, ft0.xy, fs0 <2d, clamp, linear, mipnone>',
                                'sub ft1.y, fc0.y, ft1.y ', // y-axis should increase downwards

                                // Then unpack normals from [0, 1] to [-1, 1]
                                // by multiplying by 2 and then subtracting 1

                                'mul ft1.xyz, ft1.xyz, fc0.zzz',
                                'sub ft1.xyz, ft1.xyz, fc0.yyy',
'<shadows>',
                                'nrm ft1.xyz, ft1.xyz',

                                // Sample depth to ft2

                                'tex ft2, ft0.xy, fs1 <2d, clamp, linear, mipnone>',

                                // Put specular power and specular intensity to ft0.zw
                                // Those are stored in yz of depth

                                'mov ft0.z, ft2.y',
                                'mov ft0.w, ft2.z',

                                // Calculate pixel position in eye space

                                'mul ft3.xyxy, ft0.xyxy, fc14.xyxy',
                                'mov ft3.z, fc0.w',
                                'mov ft21.xyz, ft3.xyz', // save for shadow calculations


                                'tex ft1, ft0.xy, fs4 <2d, clamp, linear, mipnone>',

                                    //'mov ft0.x, ',
                                    'mov ft0.y, fc0.w',
                                'mov ft0.z, fc0.w',
                                'mov ft0.w, fc0.y',
                                    'div ft0.x, ft0.x, fc14.x',
                                'div ft0.x, ft0.x, fc14.x',
                                'mov oc, ft0',




                            ]
                    );

            var shadowsCode:String =
                    ShaderUtils.joinProgramArray(
                            [
                                /*--------------------------
                                 Render shadows
                                 --------------------------*/

                                // Sample occluders
                                'tex ft10, ft0.xy, fs3 <2d, clamp, linear, nomip>',

                                // Calculate pixel position in lights own coordinate system, where
                                // light center is (0, 0) and Y axis increases downwards
                                'sub ft11.xy, ft21.xy, fc1.xy',
                                'div ft11.xy, ft11.xy, fc2.x',
                                'neg ft11.y, ft11.y',
                                'mov ft11.zw, fc0.ww',

                                /*--------------------------------
                                 Calculate atan2
                                 --------------------------------*/

                                // From: http://wonderfl.net/c/mS2W/

                                'abs ft8, ft11' /* ft8 = |x|, |y| */,
                                /* sge, because dated AGALMiniAssembler does not have seq */
                                'sge ft8, ft11, ft8' /* ft8.zw are both =1 now, since ft11.zw were =0 */,
                                'add ft8.xyw, ft8.xyw, ft8.xyw',
                                'sub ft8.xy, ft8.xy, ft8.zz' /* ft8 = sgn(x), sgn(y), 1, 2 */,
                                'sub ft8.w, ft8.w, ft8.x' /* ft8.w = '(partSignX, 1.0)' = 2 - sgn(x) */,
                                'mul ft8.w, ft8.w, fc9.y' /* ft8.w = '(partSignX, 1.0) * 0.7853981634' */,
                                'mul ft8.z, ft8.y, ft11.y' /* ft8.z = 'y * sign' */,
                                'add ft8.z, ft8.z, fc9.x' /* ft8.z = 'y * sign, 2.220446049250313e-16' or 'absYandR' initial value */,
                                'mul ft9.x, ft8.x, ft8.z' /* ft9.x = 'signX * absYandR' */,
                                'sub ft9.x, ft11.x, ft9.x' /* ft9.x = '(x - signX * absYandR)' */,
                                'mul ft9.y, ft8.x, ft11.x' /* ft9.y = 'signX * x' */,
                                'add ft9.y, ft9.y, ft8.z' /* ft9.y = '(signX * x, absYandR)' */,
                                'div ft8.z, ft9.x, ft9.y' /* ft8.z = '(x - signX * absYandR) / (signX * x, absYandR)' or 'absYandR' final value */,
                                'mul ft9.x, ft8.z, ft8.z' /* ft9.x = 'absYandR * absYandR' */,
                                'mul ft9.x, ft9.x, fc9.z' /* ft9.x = '0.1821 * absYandR * absYandR' */,
                                'sub ft9.x, ft9.x, fc9.w' /* ft9.x = '(0.1821 * absYandR * absYandR - 0.9675)' */,
                                'mul ft9.x, ft9.x, ft8.z' /* ft9.x = '(0.1821 * absYandR * absYandR - 0.9675) * absYandR' */,
                                'add ft9.x, ft9.x, ft8.w' /* ft9.x = '(partSignX, 1.0) * 0.7853981634, (0.1821 * absYandR * absYandR - 0.9675) * absYandR' */,
                                'mul ft9.x, ft9.x, ft8.y' /* ft9.x = '((partSignX, 1.0) * 0.7853981634, (0.1821 * absYandR * absYandR - 0.9675) * absYandR) * sign' */,
                                /* compress -pi..pi to 0..1: (angle,pi)/(2*pi) */
                                'add ft9.x, ft9.x, fc8.z',
                                'div ft9.x, ft9.x, fc8.w',

                                /*--------------------------------
                                 Apply gaussian blur
                                 --------------------------------*/

                                // float blur = (1./resolution.x)  * smoothstep(0., 1., r);
                                // smoothstep = t * t * (3.0 - 2.0 * t), t = r
                                'mul ft11.x, fc0.z, ft20.x',
                                'sub ft11.x, fc10.x, ft11.x',
                                'mul ft11.x, ft11.x, ft20.x',
                                'mul ft11.x, ft11.x, ft20.x',
                                'mul ft11.x, ft11.x, fc2.z',

                                // We`ll sum into ft12.x
                                // sum = 0
                                'mov ft12.x, fc0.w',

                                // Sample multiple times for blur
                                // sum += sample(vec2(tc.x - 4.0*blur, tc.y), r) * 0.05;
                                'mov ft13.x, ft9.x',
                                'mul ft13.y, ft11.x, fc12.w',
                                'sub ft13.x, ft13.x, ft13.y',
                                'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc11.x',
                                'add ft12.x, ft12.x, ft13.x',
                                //sum += sample(vec2(tc.x - 3.0*blur, tc.y), r) * 0.09;
                                'mov ft13.x, ft9.x',
                                'mul ft13.y, ft11.x, fc12.z',
                                'sub ft13.x, ft13.x, ft13.y',
                                'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc11.y',
                                'add ft12.x, ft12.x, ft13.x',
                                //sum += sample(vec2(tc.x - 2.0*blur, tc.y), r) * 0.12;
                                'mov ft13.x, ft9.x',
                                'mul ft13.y, ft11.x, fc12.y',
                                'sub ft13.x, ft13.x, ft13.y',
                                'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc11.z',
                                'add ft12.x, ft12.x, ft13.x',
                                //sum += sample(vec2(tc.x - 1.0*blur, tc.y), r) * 0.15;
                                'mov ft13.x, ft9.x',
                                'mul ft13.y, ft11.x, fc12.x',
                                'sub ft13.x, ft13.x, ft13.y',
                                'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc11.w',
                                'add ft12.x, ft12.x, ft13.x',
                                // sum += center * 0.16;
                                'tex ft14, ft9.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc13.x',
                                'add ft12.x, ft12.x, ft13.x',
                                //sum += sample(vec2(tc.x + 1.0*blur, tc.y), r) * 0.15;
                                'mov ft13.x, ft9.x',
                                'mul ft13.y, ft11.x, fc12.x',
                                'add ft13.x, ft13.x, ft13.y',
                                'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc11.w',
                                'add ft12.x, ft12.x, ft13.x',
                                //sum += sample(vec2(tc.x + 2.0*blur, tc.y), r) * 0.12;
                                'mov ft13.x, ft9.x',
                                'mul ft13.y, ft11.x, fc12.y',
                                'add ft13.x, ft13.x, ft13.y',
                                'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc11.z',
                                'add ft12.x, ft12.x, ft13.x',
                                //sum += sample(vec2(tc.x + 3.0*blur, tc.y), r) * 0.09;
                                'mov ft13.x, ft9.x',
                                'mul ft13.y, ft11.x, fc12.z',
                                'add ft13.x, ft13.x, ft13.y',
                                'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc11.y',
                                'add ft12.x, ft12.x, ft13.x',
                                //sum += sample(vec2(tc.x + 4.0*blur, tc.y), r) * 0.05;
                                'mov ft13.x, ft9.x',
                                'mul ft13.y, ft11.x, fc12.w',
                                'add ft13.x, ft13.x, ft13.y',
                                'tex ft14, ft13.xy, fs2 <2d, clamp, linear, nomip>',
                                'sge ft13.x, ft20.x, ft14.x',
                                'mul ft13.x, ft13.x, fc11.x',
                                'add ft12.x, ft12.x, ft13.x',

                                // Final coef
                                'sub ft12.x, fc0.y, ft12.x',

                                /*--------------------------------
                                 Result
                                 --------------------------------*/

                                // Draw shadow everywhere except pixels that overlap occluders
                                'sub ft10.x, fc0.y, ft10.x',
                                'add ft12.x, ft12.x, ft10.x',
                                'mul ft6, ft6, ft12.x'
                            ]
                    );

//            var shadowsCode:String =
//                    ShaderUtils.joinProgramArray(
//                          [
//                                  'mov oc, fc0.y',
//                          ]
//                    );

            var vertexProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
            vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, vertexProgramCode, DeferredShadingContainer.AGAL_VERSION);

            if(castsShadows)
            {
                var fragmentProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
                fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode.replace('<shadows>', shadowsCode), DeferredShadingContainer.AGAL_VERSION);

                return new Program(vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode);
            }
            else
            {
                fragmentProgramAssembler = new AGALMiniAssembler();
                fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode.replace('<shadows>', ''), DeferredShadingContainer.AGAL_VERSION);

                return new Program(vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode);
            }
        }

//        // todo
//        private function createShadowMapProgram():void
//        {
//            // Register shadowmap program
//
//            vertexProgramCode =
//                    ShaderUtils.joinProgramArray(
//                            [
//                                // Pass along unpacked screen cords
//                                'mov v0, va0',
//                                'mov op, va0'
//                            ]
//                    );
//
//            // Constants:
//            // fc0 - [uStart, vStart, uWidth, vHeight]
//            // fc1 - [PI, 1.5PI, 0, threshold]
//            // fc2 - constants [0.5, 1, 2, 0]
//            // fc3 - [boundsHeightPx, vCurrentBlockOffset, lightRadius, halfFragment]
//
//            fragmentProgramCode =
//                    ShaderUtils.joinProgramArray(
//                            [
//                                // Calculate theta (θ)
//                                // float theta = PI * 1.5 + u * PI; (u here is unpacked one, directly from varying)
//                                'mul ft0.x, v0.x, fc1.x',
//                                'add ft0.x, ft0.x, fc1.y',
//
//                                // Set initial r value to current block offset
//                                'mov ft6.x, fc3.y',
//
//                                // Set initial distance to 1
//                                'mov ft4.x, fc2.y',
//
//                                /*------------------------
//                                 LOOP GOES HERE
//                                 ------------------------*/
//                                '<loop>',
//
//                                'mov od.x, ft4.x',
//                                'mov oc, ft4.xxxx'
//                            ]
//                    );
//
//            // Calculate the number of pixels we can process using single draw call
//
//            PIXELS_PER_DRAW_CALL = Math.floor((DeferredShadingContainer.OPCODE_LIMIT - 6) / 15);
//
//            var i:int = PIXELS_PER_DRAW_CALL;
//            var loopCode:String = '';
//
//            while(i--)
//            {
//                // This renders single shadowmap pixel.
//                // Things are a bit complicated as only square portion of the occluder map should be rendered.
//                // AGAL does not support loops as of yet, so we just have to repeat needed block
//                // as many times, as it is possible while keeping opcode count below the limit.
//                // PIXELS_PER_DRAW_CALL indicates how many pixels we can process in a single draw call :~
//
//                // Constants:
//                // fc0 - [uStart, vStart, uWidth, vHeight]
//                // fc1 - [PI, 1.5PI, 0, threshold]
//                // fc2 - constants [0.5, 1, 2, 0]
//                // fc3 - [boundsHeightPx, vCurrentBlockOffset, lightRadius, 0]
//
//                // Temps:
//                // ft0 - [theta, r, u, -r]
//                // ft6.x - currY
//
//                loopCode +=
//                        ShaderUtils.joinProgramArray(
//                                [
//                                    // currU = currY / bounds.height
//                                    'div ft0.y, ft6.x, fc3.z',
//
//                                    // Calculate occluder map sample coord
//                                    // vec2 coord = vec2(-r * sin(theta), -r * cos(theta))/2.0 + 0.5;
//                                    'neg ft0.w, ft0.y',
//                                    'sin ft1.x, ft0.x',
//                                    'cos ft1.y, ft0.x',
//                                    'mul ft2.xyxy, ft0.wwww, ft1.xyxy',
//                                    'mul ft2.xyxy, ft2.xyxy, fc2.x',
//                                    'add ft2.xy, ft2.xy, fc2.x',
//
//                                    // Generated coords are in range [0, 1] so we should multiply those by
//                                    // whole shadowmap area part width and height and add offsets
//                                    'mul ft2.xyxy, ft2.xyxy, fc0.zwzw',
//                                    'add ft2.xy, ft2.xy, fc0.xy',
//                                    // Subtract half fragment - not sure why
//                                    'sub ft2.xy, ft2.xy, fc3.ww',
//                                    'tex ft3, ft2.xy, fs0 <2d, clamp, linear, mipnone>',
//
//                                    // Check if the ray hit an occluder	(meaning current occluder map value = 0)
//                                    // Set distance of this pixel to current distance if it lower than current one
//                                    'ifl ft3.x, fc2.y',
//                                    'min ft4.x, ft4.x, ft0.y',
//                                    // break/return here would speed things a lot
//                                    'eif',
//
//                                    // Increment r
//                                    'add ft6.x, ft6.x, fc2.y'
//                                ]
//                        );
//            }
//
//            // Insert loop
//
//            fragmentProgramCode = fragmentProgramCode.replace('<loop>', loopCode);
//
//            vertexProgramAssembler = new AGALMiniAssembler();
//            vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, vertexProgramCode, DeferredShadingContainer.AGAL_VERSION);
//
//            fragmentProgramAssembler = new AGALMiniAssembler();
//            fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode, DeferredShadingContainer.AGAL_VERSION);
//
//            target.registerProgram(SHADOWMAP_PROGRAM, new Program(vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode));
//
//            return Program.fromSource(vertexShader, fragmentShader);
//        }

        override protected function get programVariantName():uint
        {
            return castsShadows ? 1 : 0;
        }

        public var light:Mesh;
        public var radius:int;
        public var center:Point = new Point();
        public var castsShadows:Boolean;
        public var attenuation:Number;
        public var strength:Number;

        override protected function beforeDraw(context:Context3D):void
        {
//            sRenderAlpha[0] = sRenderAlpha[1] = sRenderAlpha[2] = 1.0;
//            sRenderAlpha[3] = alpha * this.alpha;
            sRenderAlpha[0] = sRenderAlpha[1] = sRenderAlpha[2] = sRenderAlpha[3] = alpha;

            // Set constants

            lightPosition[0] = center.x;
            lightPosition[1] = center.y;
            lightPosition[2] = radius / 2;

            // todo: think of something prettier?
            var bounds:Rectangle = light.getBounds(null, tmpBounds);
            var scaledRadius:Number = bounds.width / 2;


            lightProps[0] = scaledRadius;
            lightProps[1] = strength;
            lightProps[2] = 1 / scaledRadius;
            lightProps[3] = scaledRadius * scaledRadius;

            lightProps2[0] = castsShadows ? 1.0 : 0.0;

            lightColor[0] = 1.0//light._colorR;
            lightColor[1] = 0//light._colorG;
            lightColor[2] = 0//light._colorB;

            attenuationConstants[0] = attenuation;
            attenuationConstants[1] = 1 / (attenuationConstants[0] + 1);
            attenuationConstants[2] = 1 - attenuationConstants[1];

            screenDimensions[0] = Starling.current.stage.stageWidth;
            screenDimensions[1] = Starling.current.stage.stageHeight;

            program.activate(context);
            vertexFormat.setVertexBufferAt(0, vertexBuffer, 'position');
            context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, Starling.current.painter.state.mvpMatrix3D, true);
            context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 4, constants, 1);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, constants, 1);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, lightPosition, 1);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, lightProps, 1);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, lightColor, 1);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 4, halfVec, 1);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 5, attenuationConstants, 1);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 7, lightProps2, 1);

            if(castsShadows)
            {
                context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 8, atan2Constants, 2);
                context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 10, constants2, 1);
                context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 11, blurConstants, 3);
            }

            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 14, screenDimensions, 1);
        }

        override protected function afterDraw(context:Context3D):void
        {
            context.setVertexBufferAt(0, null);
//            context.setVertexBufferAt(1, null); todo: why this was here?
        }

        override public function get vertexFormat():VertexDataFormat
        {
            return VERTEX_FORMAT;
        }
    }
}
