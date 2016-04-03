/**
 * Created by Derpy on 2016.03.25.
 */
package starling.extensions.deferredShading.lights.rendering
{
    import com.adobe.utils.AGALMiniAssembler;

    import flash.display3D.Context3D;
    import flash.display3D.Context3DProgramType;
    import flash.display3D.Context3DVertexBufferFormat;
    import flash.display3D.IndexBuffer3D;
    import flash.display3D.VertexBuffer3D;
    import flash.geom.Point;
    import flash.geom.Rectangle;

    import starling.core.Starling;
    import starling.display.DisplayObject;
    import starling.display.Mesh;
    import starling.display.Stage;
    import starling.extensions.deferredShading.display.DeferredShadingContainer;
    import starling.extensions.deferredShading.lights.Light;
    import starling.extensions.utils.ShaderUtils;
    import starling.rendering.Painter;
    import starling.rendering.Program;
    import starling.textures.Texture;
    import starling.utils.MathUtil;

    public class SpotLightShadowMapRenderer
    {
        public static const PROGRAM_NAME:String = 'SpotLightShadowMapProgram';
        private static var PIXELS_PER_DRAW_CALL:int;

        private var constants:Vector.<Number> = new <Number>[0.5, 1.0, 2.0, 0.0];
        private var lightBounds:Vector.<Number> = new Vector.<Number>();
        private var shadowMapConstants:Vector.<Number> = new <Number>[Math.PI, Math.PI * 1.5, 0.0, 0.1];
        private var shadowMapConstants2:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
        private var tmpBounds:Rectangle = new Rectangle();
        private var pointA:Point = new Point();
        private var pointB:Point = new Point();

        /**
         * Renders shadow map for this light.
         */
        public function renderShadowMap(painter:Painter,
                                        occluders:Texture,
                                        vertexBuffer:VertexBuffer3D,
                                        indexBuffer:IndexBuffer3D,
                                        radius:Number,
                                        angle:Number,
                                        stage:Stage,
                                        light:Light,
                                        globalRotationAtCenter:Number
        ):void
        {
            createShadowMapProgram();

            light.getBounds(stage, tmpBounds);
            var context:Context3D = Starling.context;

            pointA.setTo(0, 0);
            pointB.setTo(0, radius);

            light.localToGlobal(pointA, pointA);
            light.localToGlobal(pointB, pointB);

            var dist:Number = Point.distance(pointA, pointB);
            var diag:Number = Math.sqrt(dist * dist + dist * dist);

            tmpBounds.setTo(
                    pointA.x + Math.cos(Math.PI / 2 + Math.PI / 4) * diag,
                    pointA.y - Math.sin(Math.PI / 2 + Math.PI / 4) * diag,
                    dist * 2,
                    dist * 2
            );

            // Split shadowmap generation to multiple draws as AGAL don't support loops yet
            // Offset sampling coords by half-texel to sample exactly at the middle of each texel

            // Calculate start coordinates and step sizes
            // vStart will be recalculated before each draw call

            var uStart:Number = (tmpBounds.x / stage.stageWidth) + (1 / tmpBounds.width) * 0.5;
            var vStart:Number = (tmpBounds.y / stage.stageHeight) + (1 / tmpBounds.height) * 0.5;
            var uWidth:Number = tmpBounds.width / stage.stageWidth;
            var vHeight:Number = tmpBounds.height / stage.stageHeight;
            var numBlocks:Number = Math.ceil(radius / PIXELS_PER_DRAW_CALL);
            var vCurrentBlockOffset:Number = PIXELS_PER_DRAW_CALL;

            // Set constants

            lightBounds[0] = uStart;
            lightBounds[1] = vStart;
            lightBounds[2] = uWidth;
            lightBounds[3] = vHeight;

            shadowMapConstants[0] = globalRotationAtCenter;
            shadowMapConstants[1] = angle / 2;

            shadowMapConstants2[2] = radius;
            shadowMapConstants2[3] = 1 / tmpBounds.height * 0.5;

            context.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
            context.setTextureAt(0, occluders.base);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, lightBounds);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, shadowMapConstants);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, constants);
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, shadowMapConstants2);

            Starling.painter.getProgram(PROGRAM_NAME).activate(context);

            for(var i:int = 0; i < numBlocks; i++)
            {
                shadowMapConstants2[1] = vCurrentBlockOffset * i;
                context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, shadowMapConstants2);
                context.drawTriangles(indexBuffer);
                painter.drawCount++;
            }

            // Clean up

            context.setVertexBufferAt(0, null);
            context.setTextureAt(0, null);
        }

        private function createShadowMapProgram():void
        {
            if(Starling.current.painter.getProgram(PROGRAM_NAME)) return;

            // Register shadowmap program

            var vertexProgramCode:String =
                    ShaderUtils.joinProgramArray(
                            [
                                // Pass along unpacked screen cords
                                'mov v0, va0',
                                'mov op, va0'
                            ]
                    );

            // Constants:
            // fc0 - [uStart, vStart, uWidth, vHeight]
            // fc1 - [rotationAtCenter, angle / 2, 0, threshold]
            // fc2 - constants [0.5, 1, 2, 0]
            // fc3 - [0, vCurrentBlockOffset, lightRadius, halfFragment]

            var fragmentProgramCode:String =
                    ShaderUtils.joinProgramArray(
                            [
                                // Calculate theta (θ)
                                // float theta = rotationAtCenter - angle / 2 * u (spotlight version, u is in range [-1, 1])
                                'mul ft0.x, v0.x, fc1.y',
                                'sub ft0.x, fc1.x, ft0.x',

                                // Set initial r value to current block offset
                                'mov ft6.x, fc3.y',

                                // Set initial distance to 1
                                'mov ft4.x, fc2.y',

                                /*------------------------
                                 LOOP GOES HERE
                                 ------------------------*/
                                '<loop>',

                                'mov od.x, ft4.x',
                                'mov oc, ft4.xxxx'
                            ]
                    );

            // Calculate the number of pixels we can process using single draw call

            PIXELS_PER_DRAW_CALL = Math.floor((DeferredShadingContainer.OPCODE_LIMIT - 6) / 15);

            var i:int = PIXELS_PER_DRAW_CALL;
            var loopCode:String = '';

            while(i--)
            {
                // This renders single shadowmap pixel.
                // Things are a bit complicated as only square portion of the occluder map should be rendered.
                // AGAL does not support loops as of yet, so we just have to repeat needed block
                // as many times, as it is possible while keeping opcode count below the limit.
                // PIXELS_PER_DRAW_CALL indicates how many pixels we can process in a single draw call :~

                // Constants:
                // same as above

                // Temps:
                // ft0 - [theta, r, u, -r]
                // ft6.x - currY

                loopCode +=
                        ShaderUtils.joinProgramArray(
                                [
                                    // currU = r / lightRadius
                                    'div ft0.y, ft6.x, fc3.z',

                                    // Calculate occluder map sample coord
                                    // vec2 coord = vec2(r * sin(theta), r * cos(theta))/2.0 + 0.5;
                                    'cos ft1.x, ft0.x',
                                    'sin ft1.y, ft0.x',
                                    'mul ft2.xyxy, ft1.xyxy, ft0.yyyy',
                                    'mul ft2.xyxy, ft2.xyxy, fc2.x',
                                    'neg ft2.y, ft2.y', // y axis is inverted in UV space
                                    'add ft2.xy, ft2.xy, fc2.x',

                                    // Generated coords are in range [0, 1] so we should multiply those by
                                    // whole shadowmap area part width and height and add offsets
                                    'mul ft2.xyxy, ft2.xyxy, fc0.zwzw',
                                    'add ft2.xy, ft2.xy, fc0.xy',
                                    // Subtract half fragment - not sure why
                                    'sub ft2.xy, ft2.xy, fc3.ww',
                                    'tex ft3, ft2.xy, fs0 <2d, clamp, linear, mipnone>',

                                    // Check if the ray hit an occluder	(meaning current occluder map value < 1)
                                    // Set distance of this pixel to current distance if it lower than current one
                                    'ifl ft3.x, fc2.y',
                                    'min ft4.x, ft4.x, ft0.y',
                                    // break/return here would speed things a lot
                                    'eif',

                                    // Increment r
                                    'add ft6.x, ft6.x, fc2.y'
                                ]
                        );
            }

            // Insert loop

            fragmentProgramCode = fragmentProgramCode.replace('<loop>', loopCode);

            var vertexProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
            vertexProgramAssembler.assemble(Context3DProgramType.VERTEX, vertexProgramCode, DeferredShadingContainer.AGAL_VERSION);

            var fragmentProgramAssembler:AGALMiniAssembler = new AGALMiniAssembler();
            fragmentProgramAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentProgramCode, DeferredShadingContainer.AGAL_VERSION);

            Starling.current.painter.registerProgram(PROGRAM_NAME, new Program(vertexProgramAssembler.agalcode, fragmentProgramAssembler.agalcode));
        }
    }
}
