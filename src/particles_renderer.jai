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
	scale : float = 1.0;
	color : Vector4 = .{1.0,1.0,1.0,1.0};
}

Particles_Emitter :: struct {
	position : Vector3;
	texture_alias : u32;
	duration : float = 1.0;
	counter  : float = 1.0;
	is_active : bool = false;
	drag : float = 0.96;
	particles : [..]Particle;
}

particle_systems : [..]Particles_Emitter;

particles_textures : Table(u32,TextureData);

particles_shader : u32;

particles_VBO : u32;
particles_VAO : u32;
particles_EBO : u32;

particles_model_loc : s32;
particles_view_loc : s32;
particles_projection_loc : s32;
particles_tint_loc : s32;

init_particles_renderer :: () -> u32 {
    particles_shader = create_shader_program("shaders/particles/particles_vertex.glsl","shaders/particles/particles_fragment.glsl");

    particles_model_loc = glGetUniformLocation(particles_shader,"model");
    particles_view_loc = glGetUniformLocation(particles_shader,"view");
    particles_projection_loc = glGetUniformLocation(particles_shader,"projection");
	particles_tint_loc = glGetUniformLocation(particles_shader,"tint");
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

generate_particles_system :: (texture_alias : u32, particles_count : u32, randomize_velocity : bool = true) -> *Particles_Emitter {
	new_particles : [..]Particle;
	array_resize(*new_particles,particles_count);

	//Generate particle system, add to particles to it and add it to the pool
	array_add(*particle_systems,Particles_Emitter.{texture_alias = texture_alias, particles = new_particles});

	return *particle_systems[particle_systems.count-1];
}

play_particle_system_at_point :: (particle_system : *Particles_Emitter, pos : Vector2) {
	particle_system.position = .{pos.x,pos.y,0.0};
	particle_system.counter = 0.0;
	particle_system.is_active = true;
	reset_particles(particle_system);
}

play_particle_system_random_between_two_point :: (particle_system : *Particles_Emitter, a : Vector2, b : Vector2, velocity_addition : Vector2) {

	middle_point := (a + b)/2;
	direction := (b - a);

	particle_system.position = .{0.0,0.0,0.0};
	particle_system.counter = 0.0;
	particle_system.is_active = true;
	reset_particles(particle_system);

	for *particle : particle_system.particles {
		random_point := a + direction * random_get_within_range(0.0,1.0);
		particle.position.x = random_point.x;
		particle.position.y = random_point.y;

		particle.velocity.x += velocity_addition.x;
		particle.velocity.y += velocity_addition.y;
	}
}

reset_particles :: (particle_system : *Particles_Emitter) {
	for *particle : particle_system.particles {
		particle.position = .{};
		particle.rotation = random_get_within_range(0,TAU);
		particle.scale = random_get_within_range(0.25,1.0);

		particle.velocity = Vector3.{random_get_within_range(-1.0,1.0),random_get_within_range(-1.0,1.0),0.0};
	}
}

update_particle_systems :: (dt : float) {
	for *particle_system : particle_systems {
		if !particle_system.is_active then
			continue;

		particle_system.counter += dt;

		for *particle : particle_system.particles {
			particle.position += particle.velocity*dt*100;
			particle.velocity *= particle_system.drag*dt*75;
			particle.color.w = 1.0 - particle_system.counter;
		}

		if particle_system.is_active && particle_system.counter >= particle_system.duration{
			particle_system.is_active = false;
		}
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
			glUniform4f(particles_tint_loc, particle.color.x,particle.color.y,particle.color.z,particle.color.w);
			model := translate(Matrix4_Identity,particle_system.position + particle.position) * rotate(Matrix4_Identity,get_quaternion_from_axis_and_angle(.{0,0,1},particle.rotation)) * scale(Matrix4_Identity,.{1,1,1}*particle.scale*8.0);
			glUniformMatrix4fv(particles_model_loc, 1, GL_TRUE, xx *model);

			glDrawArrays(GL_TRIANGLES,0,partices_quad_vertices.count);
		}
		//glDrawElements(GL_TRIANGLES, xx particles_indices.count, GL_UNSIGNED_INT, null);
		//print("\n%",particle_system.particles);
	}
}