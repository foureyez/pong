package chordvk

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import vk "vendor:vulkan"


GraphicsPipeline :: struct {
	vk_pipeline:        vk.Pipeline,
	layout:             vk.PipelineLayout,
	vert_shader_module: vk.ShaderModule,
	frag_shader_module: vk.ShaderModule,
}

PipelineConfig :: struct {
	vertex_input_info:       vk.PipelineVertexInputStateCreateInfo,
	viewport_info:           vk.PipelineViewportStateCreateInfo,
	input_assembly_info:     vk.PipelineInputAssemblyStateCreateInfo,
	rasterization_info:      vk.PipelineRasterizationStateCreateInfo,
	multisample_info:        vk.PipelineMultisampleStateCreateInfo,
	color_blend_attachments: [dynamic]vk.PipelineColorBlendAttachmentState,
	color_blend_info:        vk.PipelineColorBlendStateCreateInfo,
	depth_stencil_info:      vk.PipelineDepthStencilStateCreateInfo,
	dynamic_states:          [dynamic]vk.DynamicState,
	dynamic_state_info:      vk.PipelineDynamicStateCreateInfo,
	pipeline_layout:         vk.PipelineLayout,
	render_pass:             vk.RenderPass,
	subpass:                 u32,
	binding_descriptions:    []vk.VertexInputBindingDescription,
	attribute_descriptions:  []vk.VertexInputAttributeDescription,
}

create_graphics_pipeline :: proc(
	vert_filepath: string,
	frag_filepath: string,
	pl_config: ^PipelineConfig,
) -> (
	pipeline: GraphicsPipeline,
) {
	assert(pl_config.pipeline_layout != 0, "pipeline layout not set")
	assert(pl_config.render_pass != 0, "render pass not set")

	defer free_all(context.temp_allocator)

	vert_shader, vok := os.read_entire_file(filepath.join([]string{os.get_current_directory(), vert_filepath}), context.temp_allocator)
	assert(vok, fmt.tprint("unable to read vertex shader: ", vert_filepath))
	frag_shader, fok := os.read_entire_file(filepath.join([]string{os.get_current_directory(), frag_filepath}), context.temp_allocator)
	assert(vok, fmt.tprint("unable to read fragment shader: ", frag_filepath))

	pipeline.vert_shader_module = create_shader_module(vert_shader)
	pipeline.frag_shader_module = create_shader_module(frag_shader)
	pipeline.layout = pl_config.pipeline_layout


	shader_stages := []vk.PipelineShaderStageCreateInfo {
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.VERTEX},
			module = pipeline.vert_shader_module,
			pName = "main",
			flags = {},
			pNext = nil,
			pSpecializationInfo = nil,
		},
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.FRAGMENT},
			module = pipeline.frag_shader_module,
			pName = "main",
			flags = {},
			pNext = nil,
			pSpecializationInfo = nil,
		},
	}

	pipeline_info := vk.GraphicsPipelineCreateInfo {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount          = 2,
		pStages             = raw_data(shader_stages),
		pVertexInputState   = &vk.PipelineVertexInputStateCreateInfo {
			sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
			vertexAttributeDescriptionCount = u32(len(pl_config.attribute_descriptions)),
			vertexBindingDescriptionCount = u32(len(pl_config.binding_descriptions)),
			pVertexAttributeDescriptions = raw_data(pl_config.attribute_descriptions),
			pVertexBindingDescriptions = raw_data(pl_config.binding_descriptions),
		},
		pInputAssemblyState = &pl_config.input_assembly_info,
		pViewportState      = &pl_config.viewport_info,
		pRasterizationState = &pl_config.rasterization_info,
		pMultisampleState   = &pl_config.multisample_info,
		pColorBlendState    = &pl_config.color_blend_info,
		pDepthStencilState  = &pl_config.depth_stencil_info,
		pDynamicState       = &pl_config.dynamic_state_info,
		layout              = pl_config.pipeline_layout,
		renderPass          = pl_config.render_pass,
		subpass             = pl_config.subpass,
		basePipelineIndex   = -1,
		basePipelineHandle  = 0,
	}

	assert(
		vk.CreateGraphicsPipelines(vk_ctx.device.handle, 0, 1, &pipeline_info, nil, &pipeline.vk_pipeline) == .SUCCESS,
		"unable to create graphics pipeline",
	)

	return pipeline
}

destroy_pipeline :: proc(pl: GraphicsPipeline) {
	vk.DestroyShaderModule(vk_ctx.device.handle, pl.vert_shader_module, nil)
	vk.DestroyShaderModule(vk_ctx.device.handle, pl.frag_shader_module, nil)
	vk.DestroyPipeline(vk_ctx.device.handle, pl.vk_pipeline, nil)
}

bind_pipeline :: proc(command_buffer: vk.CommandBuffer, descriptor_set: ^vk.DescriptorSet) {
	vk.CmdBindPipeline(command_buffer, .GRAPHICS, vk_ctx.graphics_pipeline.vk_pipeline)
	vk.CmdBindDescriptorSets(command_buffer, .GRAPHICS, vk_ctx.graphics_pipeline.layout, 0, 1, descriptor_set, 0, nil)
}

default_pipeline_config :: proc() -> (config: PipelineConfig) {
	config.input_assembly_info = vk.PipelineInputAssemblyStateCreateInfo {
		sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology               = .TRIANGLE_LIST,
		primitiveRestartEnable = false,
	}

	config.viewport_info = vk.PipelineViewportStateCreateInfo {
		sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		pViewports    = nil,
		scissorCount  = 1,
		pScissors     = nil,
	}

	append(&config.dynamic_states, vk.DynamicState.VIEWPORT, vk.DynamicState.SCISSOR)
	config.dynamic_state_info = vk.PipelineDynamicStateCreateInfo {
		sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		pDynamicStates    = raw_data(config.dynamic_states),
		dynamicStateCount = 2,
		flags             = {},
	}

	config.rasterization_info = vk.PipelineRasterizationStateCreateInfo {
		sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		depthClampEnable        = false,
		rasterizerDiscardEnable = false,
		polygonMode             = .FILL,
		lineWidth               = 1.0,
		cullMode                = vk.CullModeFlags_NONE,
		frontFace               = .CLOCKWISE,
		depthBiasEnable         = false,
		depthBiasConstantFactor = 0.0,
		depthBiasClamp          = 0.0,
		depthBiasSlopeFactor    = 0.0,
	}

	config.multisample_info = vk.PipelineMultisampleStateCreateInfo {
		sType                 = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		sampleShadingEnable   = false,
		rasterizationSamples  = {._1},
		minSampleShading      = 1.0,
		pSampleMask           = nil,
		alphaToCoverageEnable = false,
		alphaToOneEnable      = false,
	}

	append(
		&config.color_blend_attachments,
		vk.PipelineColorBlendAttachmentState {
			colorWriteMask = {.R, .G, .B, .A},
			blendEnable = false,
			srcColorBlendFactor = .ONE,
			dstColorBlendFactor = .ZERO,
			colorBlendOp = .ADD,
			srcAlphaBlendFactor = .ONE,
			dstAlphaBlendFactor = .ZERO,
			alphaBlendOp = .ADD,
		},
	)

	config.color_blend_info = vk.PipelineColorBlendStateCreateInfo {
		sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		logicOpEnable   = false,
		logicOp         = .COPY,
		attachmentCount = 1,
		blendConstants  = {0.0, 0.0, 0.0, 0.0},
		pAttachments    = raw_data(config.color_blend_attachments),
	}

	config.depth_stencil_info = vk.PipelineDepthStencilStateCreateInfo {
		sType                 = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
		depthTestEnable       = true,
		depthWriteEnable      = true,
		depthCompareOp        = .LESS,
		depthBoundsTestEnable = false,
		minDepthBounds        = 0.0, // Optional
		maxDepthBounds        = 1.0, // Optional
		stencilTestEnable     = false,
		front                 = {}, // Optional
		back                  = {}, // Optional
	}

	return config
}

create_pipeline_layout :: proc(ds_layout: vk.DescriptorSetLayout) -> (layout: vk.PipelineLayout) {
	push_constant_range := vk.PushConstantRange {
		stageFlags = {.VERTEX, .FRAGMENT}, // NOT {.FRAGMENT|.VERTEX} 
		offset     = 0,
		size       = size_of(TransformPushConstantData),
	}
	descriptor_set_layouts := []vk.DescriptorSetLayout{ds_layout}
	pipeline_layout_info := vk.PipelineLayoutCreateInfo {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount         = u32(len(descriptor_set_layouts)),
		pSetLayouts            = raw_data(descriptor_set_layouts),
		pushConstantRangeCount = 1,
		pPushConstantRanges    = &push_constant_range,
	}

	assert(
		vk.CreatePipelineLayout(vk_ctx.device.handle, &pipeline_layout_info, nil, &layout) == .SUCCESS,
		"unable to create pipeline layout",
	)
	return layout
}

@(private)
create_shader_module :: proc(code: []byte) -> vk.ShaderModule {
	shader_module: vk.ShaderModule
	as_u32 := slice.reinterpret([]u32, code)
	create_info := vk.ShaderModuleCreateInfo{}
	create_info.sType = .SHADER_MODULE_CREATE_INFO
	create_info.codeSize = len(code)
	create_info.pCode = raw_data(as_u32)

	assert(vk.CreateShaderModule(vk_ctx.device.handle, &create_info, nil, &shader_module) == .SUCCESS, "unable to create shader module")
	return shader_module
}
