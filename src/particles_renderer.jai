partices_quad_vertices := float.[
    -0.5,-0.5,0.0,0.0,
     0.5,-0.5,1.0,0.0,
     0.5, 0.5,1.0,1.0,

     0.5, 0.5,1.0,1.0,
    -0.5, 0.5,0.0,1.0,
    -0.5,-0.5,0.0,0.0,
];

particles_indices := u32.[
    0,1,2,
    0,2,3
];

TextureData :: struct {
	id : u32;
	width : s32;
	height : s32;
}

Particle :: struct {
	position : Vector3;
	velocity : Vector3 = Vector3.{1.0,0.0,0.0};
	rotation : float;
	scale : float = 8.0;
}

ParticleSystem :: struct {
	position : Vector3;
	texture_alias : u32;
	duration : float = 1.0;
	counter  : float = 1.0;
	is_active : bool = false;
	particles : [..]Particle;
}

particle_systems : [..]ParticleSystem;

particles_textures : Table(u32,TextureData);

particles_shader : u32;

particles_VBO : u32;
particles_VAO : u32;
particles_EBO : u32;

particles_model_loc : s32;
particles_view_loc : s32;
particles_projection_loc : s32;
particles_texture_loc : s32;

init_particles_renderer :: () -> u32 {
    particles_shader = create_shader_program("shaders/particles/particles_vertex.glsl","shaders/particles/particles_fragment.glsl");

    particles_model_loc = glGetUniformLocation(particles_shader,"model");
    particles_view_loc = glGetUniformLocation(particles_shader,"view");
    particles_projection_loc = glGetUniformLocation(particles_shader,"projection");
	particles_texture_loc = glGetUniformLocation(particles_shader,"text");

	//VAO
	glGenVertexArrays(1,*particles_VAO);
	glBindVertexArray(particles_VAO);
    //VBO
	glGenBuffers(1,*particles_VBO);
	glBindBuffer(GL_ARRAY_BUFFER,particles_VBO);
	glBufferData(GL_ARRAY_BUFFER,partices_quad_vertices.count*size_of(float),*partices_quad_vertices,GL_STATIC_DRAW);

	//Vertices pointers
	glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,4*size_of(float),xx 0);
	glEnableVertexAttribArray(0);
	//UVs pointers
	glVertexAttribPointer(1,2,GL_FLOAT,GL_FALSE,4*size_of(float),xx (2 * size_of(float)));
	glEnableVertexAttribArray(1);
	//EBO
	//glGenBuffers(1,*particles_EBO);
	//glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, particles_EBO);
	//glBufferData(GL_ELEMENT_ARRAY_BUFFER,particles_indices.count*size_of(u32),*particles_indices,GL_STATIC_DRAW);
    return particles_shader;
}

generate_particles_texture :: (texture_alias : u32, texture_file_path : string) {
	new_texture : u32;
	glGenTextures(1,*new_texture);
	glBindTexture(GL_TEXTURE_2D, new_texture);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	nr_channels : s32;
	width : s32;
	height : s32;

	texture := stbi_load(texture_file_path.data,*width,*height,*nr_channels,4);
	defer stbi_image_free(texture);
	if !texture {
		error := tprint("\nFailed to load texture: %",texture_file_path);
		print(error);
		return;
	}
	glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA, xx width, xx height,0,GL_RGBA,GL_UNSIGNED_BYTE,texture);
	glGenerateMipmap(GL_TEXTURE_2D);

	table_add(*particles_textures,texture_alias,.{xx new_texture,width,height});
}

generate_particles_system :: (texture_alias : u32, particles_count : u32, randomize_velocity : bool = true) -> *ParticleSystem {
	new_particles : [..]Particle;
	array_resize(*new_particles,particles_count);

	for *particle : new_particles {
		particle.velocity = Vector3.{random_get_within_range(-1.0,1.0),random_get_within_range(-1.0,1.0),0.0};
	}

	//Generate particle system, add to particles to it and add it to the pool
	array_add(*particle_systems,ParticleSystem.{texture_alias = texture_alias, particles = new_particles});

	return *particle_systems[particle_systems.count-1];
}

play_particle_system_at :: (particle_system : *ParticleSystem, pos : Vector2) {
	particle_system.position = .{pos.x,pos.y,0.0};
	particle_system.counter = 0.0;
	particle_system.is_active = true;
	reset_particles(particle_system);

}

update_particle_systems :: (delta : float) {
	for *particle_system : particle_systems {
		if !particle_system.is_active then
			continue;

		particle_system.counter += delta;

		for *particle : particle_system.particles {
			particle.position += particle.velocity;
		}

		if particle_system.is_active && particle_system.counter >= particle_system.duration{
			particle_system.is_active = false;
			print("\nDisabled"); //nocheckin
		}
	}
}

reset_particles :: (particle_system : *ParticleSystem) {
	for *particle : particle_system.particles {
		particle.position = .{};
	}
}

draw_particles_systems :: (view : *Matrix4, projection : *Matrix4) {

	glUseProgram(particles_shader);

	glBindVertexArray(particles_VAO);
	glBindBuffer(GL_ARRAY_BUFFER,particles_VBO);

	glUniformMatrix4fv(particles_view_loc, 1, GL_TRUE, xx view);
    glUniformMatrix4fv(particles_projection_loc, 1, GL_TRUE, xx projection);

	for particle_system : particle_systems {
		if !particle_system.is_active then
				continue;
		texture_data, success := table_find(*particles_textures,particle_system.texture_alias);
		glBindTexture(GL_TEXTURE_2D, texture_data.id);

		for particle : particle_system.particles {
			model := translate(Matrix4_Identity,particle_system.position + particle.position) * scale(Matrix4_Identity,.{1,1,1}*particle.scale);
			glUniformMatrix4fv(particles_model_loc, 1, GL_TRUE, xx *model);

			glDrawArrays(GL_TRIANGLES,0,partices_quad_vertices.count);
		}
		//glDrawElements(GL_TRIANGLES, xx particles_indices.count, GL_UNSIGNED_INT, null);
		//print("\n%",particle_system.particles);
	}
}