(function() {
    'use strict';

    R.particleRender = function(state) {
		if (!R.progParticle) {
			console.log('waiting for programs to load...');
			return;
		}
		
		// Collision
		// Bind collision shaders, bind position + vel textures -> write to force texture
		
		// Render
		// Bind render shaders, bind position texture -> vertex shader transforms particles to new positions
		renderParticles(state, R.progParticle);

		// Update state
		// Bind update shaders, bind force texture -> write to velocity and position texture
		updateParticles(state, R.progUpdate);
    };
    
	
	var renderParticles = function(state, prog) {
		gl.bindFramebuffer(gl.FRAMEBUFFER, null);

		// Use the program
		gl.useProgram(prog.prog);
		
		var m = state.cameraMat.elements;
		gl.uniformMatrix4fv(prog.u_cameraMat, false, m);

		gl.bindBuffer(gl.ARRAY_BUFFER, R.uvCoords);
		gl.enableVertexAttribArray(prog.a_uv);
		gl.vertexAttribPointer(prog.a_uv, 2, gl.FLOAT, gl.FALSE, 0, 0);

		// Bind position texture
		bindTextures(prog, prog.u_posTex,
			R.currentPosFbo === R.posFboA ? R.positionTexA : R.positionTexB);
		
		gl.clearColor(0.5, 0.5, 0.5, 0.9);
		gl.enable(gl.DEPTH_TEST);
		gl.clear(gl.COLOR_BUFFER_BIT);

		gl.drawArrays(gl.POINTS, 0, 64);
	}

	var updateParticles = function(state, prog) {
		//gl.bindFramebuffer(gl.FRAMEBUFFER, null);
		// Use the program
		gl.useProgram(prog.prog);

		if (cfg.pingPong) {
			if (R.currentPosFbo === R.posFboA) {
				bindTextures(prog, prog.u_posTex, R.positionTexA);
				gl.bindFramebuffer(gl.FRAMEBUFFER, R.posFboB);
				R.currentPosFbo = R.posFboB;
			}
			else {

					bindTextures(prog, prog.u_posTex, R.positionTexB);
					gl.bindFramebuffer(gl.FRAMEBUFFER, R.posFboA);
					R.currentPosFbo = R.posFboA;
			}

			renderFullScreenQuad(prog);

		}

		if (cfg.showTexture) {
			bindTextures(prog, prog.u_posTex, R.positionTexA);
			gl.bindFramebuffer(gl.FRAMEBUFFER, null);
			renderFullScreenQuad(prog);
		}
	}

	var bindTextures = function(prog, location, tex) {
		gl.useProgram(prog.prog);
		gl.activeTexture(gl['TEXTURE0']);
        gl.bindTexture(gl.TEXTURE_2D, tex);
        gl.uniform1i(location, 0);
	}

	var renderFullScreenQuad = (function() {
		var positions = new Float32Array([
			-1.0, -1.0, 0.0,
			1.0, -1.0, 0.0,
			-1.0,  1.0, 0.0,
			1.0,  1.0, 0.0
		]);

		var vbo = null;

		var init = function() {
			// Create a new buffer with gl.createBuffer, and save it as vbo.
			vbo = gl.createBuffer();

			// Bind the VBO as the gl.ARRAY_BUFFER
			gl.bindBuffer(gl.ARRAY_BUFFER,vbo);

			// Upload the positions array to the currently-bound array buffer
			// using gl.bufferData in static draw mode.
			gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW);
		};

		return function(prog) {
			if (!vbo) {
				// If the vbo hasn't been initialized, initialize it.
				init();
			}

			// Bind the program to use to draw the quad
			gl.useProgram(prog.prog);

			// Bind the position array to the vbo
			gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
			gl.enableVertexAttribArray(prog.a_position);
			gl.vertexAttribPointer(prog.a_position, 3, gl.FLOAT, gl.FALSE, 0, 0);

			// Use gl.drawArrays (or gl.drawElements) to draw your quad.
			gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

			// Unbind the array buffer.
			gl.bindBuffer(gl.ARRAY_BUFFER, null);
		};
	})();

})();
