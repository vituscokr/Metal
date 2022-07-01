import Cocoa
import PlaygroundSupport
import MetalKit

///Initialize Metal
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("GPU is not supported")
}
///메발뷰를 설정합니다.
let frame = CGRect(x: 0, y:0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)
///메탈 뷰의 백그라운 색깔을 지정 합니다.
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)

///load a Model
///Model I/0  를 통한 3D 모델을 가지고 옴
///메시데이타에 대한 메모리 관리자
let allocator = MTKMeshBufferAllocator(device: device)
/// Model Mesh 데이타 생성
/// MDLMesh : A container for vertex buffer data to be used in rendering a 3D object.
///
let mdlMesh = MDLMesh(sphereWithExtent: [0.75,0.75,0.75],
                      segments: [100,100],
                      inwardNormals: false,
                      geometryType: .triangles,
                      allocator: allocator)
/// For Metal to be able to use the mesh, you convert it from a Model I/O mesh to a MetalKit mesh.
let mesh = try MTKMesh(mesh: mdlMesh , device: device)


///Setup pipeline
///
///Each frame consists of commands that you send to the GPU. You wrap up these
///commands in a render command encoder. Command buffers organize these
///command encoders and a command queue organizes the command buffers.
///
guard let commandQueue = device.makeCommandQueue() else {
    fatalError("Could not create a commnd queue")
}

///Metal Shading Language which is a subset of C++.
let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
    return vertex_in.position;
}

fragment float4 fragment_main() {
    return float4(1,0,0,1);
}
"""

let library = try device.makeLibrary(source: shader, options: nil)
///pipeline descriptor.
///shader functions
let vertexFuction = library.makeFunction(name: "vertex_main")
let fragmentFuction = library.makeFunction(name: "fragment_main")


///The pipeline state
let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
pipelineDescriptor.vertexFunction = vertexFuction
pipelineDescriptor.fragmentFunction = fragmentFuction

pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)


///Render
///Render passes (Single render pass)
guard let commandBuffer = commandQueue.makeCommandBuffer(),
      ///You obtain a reference to the view’s render pass descriptor
      let renderPassDesciptor = view.currentRenderPassDescriptor,
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesciptor)
else {
    fatalError("render failed")
}
renderEncoder.setRenderPipelineState(pipelineState)
///The offset is the position in the buffer where the vertex information starts. The index is how the GPU vertex shader function will locate this buffer.
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

///
guard let submesh = mesh.submeshes.first else {
    fatalError()
}

//draw call
renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)
///You tell the render encoder that there are no more draw calls.
renderEncoder.endEncoding()
///You get the drawable from the MTKView . The MTKView is backed by a Core Animation CAMetalLayer and the layer owns a drawable texture which Metal can read and write to.

guard let drawable = view.currentDrawable else {
    fatalError()
}
//Ask the command buffer to present the MTKView ’s drawable and commit to the GPU.
commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view

        
