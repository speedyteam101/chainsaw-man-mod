using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using ReLogic.Content;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent;
using Terraria.Graphics.CameraModifiers;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Projectiles
{
	// The Orbital Cannon Strike. The projectile sits on the impact point and runs in three phases:
	//  1. Lock-on:  a satellite slides into view high above, a reticle spins down onto the target
	//               and a thin red guide laser flickers between them while the cannon charges.
	//  2. Fire:     a huge beam slams down from the satellite to the ground, with a shockwave, screen shake,
	//               sparks, smoke and light. Everything inside the beam takes damage several times.
	//  3. Fade:     the beam narrows and fades out.
	// The beam cuts through blocks (it's fired from orbit), but doesn't break them.
	public class OrbitalStrike : ModProjectile
	{
		public const int LockOnTime = 70;
		public const int FireTime = 80;
		public const int FadeTime = 20;
		public const int TotalTime = LockOnTime + FireTime + FadeTime;

		public const float BeamWidth = 110f;     // at full power, in pixels
		public const float BeamHeight = 2400f;   // how far up the beam reaches (well above the top of the screen)
		public const float ImpactRadius = 160f;  // extra blast area around the impact point

		private static readonly Color BeamOuter = new Color(40, 140, 255);
		private static readonly Color BeamMid = new Color(90, 230, 255);
		private static readonly Color BeamCore = new Color(235, 255, 255);
		private static readonly Color LockColor = new Color(255, 60, 60);

		private const string Path = "RobotJack/Content/Projectiles/";
		private static Asset<Texture2D> satelliteTex, beamTex, glowTex, ringTex;

		// Ticks since the strike was called in.
		private int Timer {
			get => (int)Projectile.ai[0];
			set => Projectile.ai[0] = value;
		}

		private bool Firing => Timer >= LockOnTime;

		// Only the owner knows where it clicked, so it moves the projectile down onto the ground below the cursor.
		// Keeps the click point if it's inside blocks (the beam still reaches down to it).
		public static Vector2 FindImpactPoint(Vector2 cursor) {
			int x = (int)(cursor.X / 16f);
			int y = (int)(cursor.Y / 16f);
			for (int i = 0; i < 60; i++) {
				if (!WorldGen.InWorld(x, y + i, 10)) {
					break;
				}
				if (WorldGen.SolidTile(x, y + i)) {
					return new Vector2(cursor.X, (y + i) * 16f);
				}
			}
			return cursor;
		}

		public override void SetStaticDefaults() {
			// Keep drawing the beam even when the impact point itself is off screen.
			ProjectileID.Sets.DrawScreenCheckFluff[Type] = (int)BeamHeight + 400;

			if (!Main.dedServ) {
				satelliteTex = ModContent.Request<Texture2D>(Path + "OrbitalSatellite");
				beamTex = ModContent.Request<Texture2D>(Path + "OrbitalBeam");
				glowTex = ModContent.Request<Texture2D>(Path + "OrbitalGlow");
				ringTex = ModContent.Request<Texture2D>(Path + "OrbitalRing");
			}
		}

		public override void Unload() {
			satelliteTex = beamTex = glowTex = ringTex = null;
		}

		public override void SetDefaults() {
			Projectile.width = 16;
			Projectile.height = 16;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Ranged;
			Projectile.penetrate = -1;
			Projectile.tileCollide = false;
			Projectile.ignoreWater = true;
			Projectile.timeLeft = TotalTime;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = 8;
			Projectile.aiStyle = -1;
		}

		public override bool ShouldUpdatePosition() => false;

		public override bool? CanCutTiles() => false;

		// 0 before firing, ramps to 1 quickly, flickers slightly while firing, then fades to 0.
		private float Power() {
			if (!Firing) {
				return 0f;
			}
			int t = Timer - LockOnTime;
			float power;
			if (t < 6) {
				power = t / 6f;
			}
			else if (t < FireTime) {
				power = 1f;
			}
			else {
				power = 1f - (t - FireTime) / (float)FadeTime;
			}
			power *= 1f + 0.06f * (float)System.Math.Sin(Timer * 0.9f);
			return MathHelper.Clamp(power, 0f, 1.1f);
		}

		// Where the satellite hangs: near the top of the view, or well above the target if that's higher.
		private Vector2 SatellitePosition() {
			float top = Main.screenPosition.Y + 70f;
			float y = System.Math.Min(top, Projectile.Center.Y - 320f);
			// Slides down into place during the first 25 ticks.
			float slide = MathHelper.Clamp(Timer / 25f, 0f, 1f);
			y -= (1f - slide) * (1f - slide) * 260f;
			return new Vector2(Projectile.Center.X, y);
		}

		public override void AI() {
			Timer++;

			if (Timer == 1) {
				SoundEngine.PlaySound(SoundID.Item15 with { Pitch = -0.6f, Volume = 1.2f }, Projectile.Center);
			}

			if (!Firing) {
				LockOnEffects();
			}
			else {
				if (Timer == LockOnTime) {
					OnFire();
				}
				FiringEffects();
			}
		}

		private void LockOnEffects() {
			// Lock-on beeps that speed up as the charge completes.
			int beepEvery = Timer < LockOnTime / 2 ? 14 : 7;
			if (Timer % beepEvery == 0 && Main.myPlayer == Projectile.owner) {
				SoundEngine.PlaySound(SoundID.MenuTick with { Pitch = 0.4f + Timer / (float)LockOnTime, Volume = 1.5f }, Projectile.Center);
			}

			// Energy gathering at the satellite's cannon.
			Vector2 emitter = SatellitePosition() + new Vector2(0f, 50f);
			float charge = Timer / (float)LockOnTime;
			for (int i = 0; i < 2; i++) {
				Vector2 offset = Main.rand.NextVector2CircularEdge(60f, 60f) * (1.2f - charge);
				Dust dust = Dust.NewDustPerfect(emitter + offset, DustID.Electric, -offset * 0.08f, Scale: 0.9f + charge);
				dust.noGravity = true;
			}

			// Red targeting sparks on the ground.
			if (Main.rand.NextBool(3)) {
				Dust dust = Dust.NewDustPerfect(Projectile.Center + Main.rand.NextVector2Circular(30f, 4f), DustID.Torch, new Vector2(0f, -1.5f), Scale: 1.1f);
				dust.noGravity = true;
			}
			Lighting.AddLight(Projectile.Center, 0.6f * charge, 0.1f, 0.1f);
		}

		private void OnFire() {
			SoundEngine.PlaySound(SoundID.Item122 with { Pitch = -0.4f, Volume = 1.4f }, Projectile.Center);
			SoundEngine.PlaySound(SoundID.Item14 with { Pitch = -0.5f, Volume = 1.5f }, Projectile.Center);
			SoundEngine.PlaySound(SoundID.Item62 with { Pitch = -0.3f }, Projectile.Center);

			// Screen shake, strongest near the impact.
			PunchCameraModifier shake = new PunchCameraModifier(Projectile.Center, Main.rand.NextVector2Unit(), 18f, 8f, 40, 2000f, FullName);
			Main.instance.CameraModifiers.Add(shake);

			// Ground burst: sparks, fire and smoke thrown outward.
			for (int i = 0; i < 70; i++) {
				Vector2 vel = new Vector2(Main.rand.NextFloat(-14f, 14f), Main.rand.NextFloat(-12f, -1f));
				Dust spark = Dust.NewDustPerfect(Projectile.Center, DustID.Electric, vel, Scale: Main.rand.NextFloat(1f, 1.8f));
				spark.noGravity = Main.rand.NextBool();
			}
			for (int i = 0; i < 40; i++) {
				Vector2 vel = new Vector2(Main.rand.NextFloat(-9f, 9f), Main.rand.NextFloat(-7f, 0f));
				Dust.NewDustPerfect(Projectile.Center, DustID.Torch, vel, Scale: Main.rand.NextFloat(1.5f, 2.5f)).noGravity = true;
			}
			for (int i = 0; i < 30; i++) {
				Vector2 vel = new Vector2(Main.rand.NextFloat(-6f, 6f), Main.rand.NextFloat(-4f, 0f));
				Dust.NewDustPerfect(Projectile.Center, DustID.Smoke, vel, 100, default, Main.rand.NextFloat(1.5f, 2.5f));
			}
		}

		private void FiringEffects() {
			float power = Power();
			float width = BeamWidth * power;

			// Energy streaks racing down the beam.
			for (int i = 0; i < 3; i++) {
				Vector2 pos = Projectile.Center + new Vector2(Main.rand.NextFloat(-width * 0.4f, width * 0.4f), -Main.rand.NextFloat(0f, 900f));
				Dust dust = Dust.NewDustPerfect(pos, DustID.Electric, new Vector2(0f, Main.rand.NextFloat(10f, 18f)), Scale: 1.2f);
				dust.noGravity = true;
			}

			// Constant spray of sparks and smoke at the impact point.
			if (power > 0.3f) {
				for (int i = 0; i < 4; i++) {
					Vector2 vel = new Vector2(Main.rand.NextFloat(-10f, 10f), Main.rand.NextFloat(-8f, -2f));
					Dust.NewDustPerfect(Projectile.Center + new Vector2(Main.rand.NextFloat(-width / 2, width / 2), 0f), DustID.Electric, vel, Scale: 1.3f);
				}
				if (Main.rand.NextBool(2)) {
					Dust.NewDustPerfect(Projectile.Center + new Vector2(Main.rand.NextFloat(-width, width), -8f),
						DustID.Smoke, new Vector2(Main.rand.NextFloat(-2f, 2f), -Main.rand.NextFloat(1f, 3f)), 120, default, 2f);
				}
			}

			// Light up the whole column.
			for (float y = 0; y < 1400f; y += 32f) {
				Lighting.AddLight(Projectile.Center - new Vector2(0f, y), 0.3f * power, 0.8f * power, 1.1f * power);
			}
			Lighting.AddLight(Projectile.Center, 1.5f * power, 2f * power, 2.5f * power);

			// A lighter rumble while the beam is sustained.
			if (Timer % 20 == 0 && power > 0.5f) {
				Main.instance.CameraModifiers.Add(new PunchCameraModifier(Projectile.Center, Main.rand.NextVector2Unit(), 4f, 10f, 20, 1500f, FullName));
			}
		}

		public override bool? Colliding(Rectangle projHitbox, Rectangle targetHitbox) {
			float power = Power();
			if (power <= 0.2f) {
				return false;
			}

			// The beam column, from high above down to (slightly below) the impact point.
			float width = BeamWidth * power;
			Rectangle beam = new Rectangle((int)(Projectile.Center.X - width / 2f), (int)(Projectile.Center.Y - BeamHeight), (int)width, (int)BeamHeight + 24);
			if (beam.Intersects(targetHitbox)) {
				return true;
			}

			// The blast around the impact point.
			float closestX = MathHelper.Clamp(Projectile.Center.X, targetHitbox.Left, targetHitbox.Right);
			float closestY = MathHelper.Clamp(Projectile.Center.Y, targetHitbox.Top, targetHitbox.Bottom);
			return Vector2.Distance(Projectile.Center, new Vector2(closestX, closestY)) < ImpactRadius * power;
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			target.AddBuff(BuffID.Electrified, 180);
			target.AddBuff(BuffID.OnFire3, 180);
			for (int i = 0; i < 6; i++) {
				Dust.NewDustDirect(target.position, target.width, target.height, DustID.Electric, 0f, -3f).noGravity = true;
			}
		}

		// ------------------------------------------------------------------ drawing

		// Colour with alpha 0 draws additively with the normal sprite batch, so overlapping layers glow.
		private static Color Glow(Color color, float opacity) => new Color(color.R, color.G, color.B, 0) * opacity;

		public override bool PreDraw(ref Color lightColor) {
			Vector2 ground = Projectile.Center - Main.screenPosition;
			Vector2 satellite = SatellitePosition() - Main.screenPosition;
			Vector2 emitter = satellite + new Vector2(0f, 50f);
			float fadeOut = Timer > LockOnTime + FireTime ? 1f - (Timer - LockOnTime - FireTime) / (float)FadeTime : 1f;

			if (!Firing) {
				DrawLockOn(ground, emitter);
			}
			else {
				DrawBeam(ground, emitter);
			}

			// Satellite on top of the beam's upper end, fading away at the very end.
			Texture2D sat = satelliteTex.Value;
			float bob = (float)System.Math.Sin(Timer * 0.08f) * 3f;
			Main.EntitySpriteDraw(sat, satellite + new Vector2(0f, bob), null, Color.White * fadeOut, 0f, sat.Size() / 2f, 1f, SpriteEffects.None, 0);

			// Charge glow at the satellite's cannon.
			float charge = Firing ? Power() : Timer / (float)LockOnTime;
			Texture2D glow = glowTex.Value;
			Main.EntitySpriteDraw(glow, emitter + new Vector2(0f, bob), null, Glow(BeamMid, 0.9f * charge), 0f, glow.Size() / 2f, 0.4f + charge * 0.9f, SpriteEffects.None, 0);
			Main.EntitySpriteDraw(glow, emitter + new Vector2(0f, bob), null, Glow(BeamCore, charge), 0f, glow.Size() / 2f, 0.2f + charge * 0.4f, SpriteEffects.None, 0);
			return false;
		}

		private void DrawLockOn(Vector2 ground, Vector2 emitter) {
			float progress = Timer / (float)LockOnTime;
			Texture2D reticle = TextureAssets.Projectile[Type].Value;
			Texture2D beam = beamTex.Value;

			// Flickering thin guide laser from the satellite to the target.
			if (Timer > 20 && Timer % 6 != 0) {
				float length = ground.Y - emitter.Y;
				if (length > 0f) {
					Vector2 scale = new Vector2(4f / beam.Width, length / beam.Height);
					Main.EntitySpriteDraw(beam, new Vector2(ground.X, emitter.Y), null, Glow(LockColor, 0.7f), 0f, new Vector2(beam.Width / 2f, 0f), scale, SpriteEffects.None, 0);
				}
			}

			// Reticle shrinks and spins down onto the target, flashing faster as it locks.
			float scaleR = MathHelper.Lerp(3f, 1f, System.Math.Min(progress * 1.4f, 1f));
			bool flash = progress > 0.6f && Timer / 4 % 2 == 0;
			Color color = flash ? Color.White : LockColor;
			Main.EntitySpriteDraw(reticle, ground, null, Glow(color, 0.9f), Timer * 0.08f, reticle.Size() / 2f, scaleR, SpriteEffects.None, 0);
			Main.EntitySpriteDraw(reticle, ground, null, Glow(color, 0.5f), -Timer * 0.05f, reticle.Size() / 2f, scaleR * 0.55f, SpriteEffects.None, 0);

			// Warning glow on the ground.
			Texture2D glow = glowTex.Value;
			Main.EntitySpriteDraw(glow, ground, null, Glow(LockColor, 0.5f * progress), 0f, glow.Size() / 2f, new Vector2(2f, 0.5f) * (0.5f + progress), SpriteEffects.None, 0);
		}

		private void DrawBeam(Vector2 ground, Vector2 emitter) {
			float power = Power();
			if (power <= 0f) {
				return;
			}
			Texture2D beam = beamTex.Value;
			Texture2D glow = glowTex.Value;
			Texture2D ring = ringTex.Value;

			float length = ground.Y - emitter.Y + 10f;
			if (length > 0f) {
				Vector2 top = new Vector2(ground.X, emitter.Y);
				Vector2 origin = new Vector2(beam.Width / 2f, 0f);
				// Wide soft glow, main beam, then a hot white core. A little horizontal jitter makes it crackle.
				float jitter = Main.rand.NextFloat(-2f, 2f);
				DrawBeamLayer(beam, top + new Vector2(jitter, 0f), origin, BeamWidth * power * 2.2f, length, Glow(BeamOuter, 0.45f));
				DrawBeamLayer(beam, top, origin, BeamWidth * power * 1.2f, length, Glow(BeamMid, 0.85f));
				DrawBeamLayer(beam, top - new Vector2(jitter, 0f), origin, BeamWidth * power * 0.5f, length, Glow(BeamCore, 1f));
				DrawBeamLayer(beam, top, origin, BeamWidth * power * 0.2f, length, Glow(Color.White, 1f));

				// Bright bands sliding down the beam.
				for (int i = 0; i < 4; i++) {
					float y = (Timer * 40f + i * length / 4f) % length;
					Main.EntitySpriteDraw(glow, top + new Vector2(0f, y), null, Glow(BeamCore, 0.35f * power), 0f, glow.Size() / 2f,
						new Vector2(BeamWidth * power * 1.3f / glow.Width, 1.4f), SpriteEffects.None, 0);
				}
			}

			// Impact flare on the ground.
			float pulse = 1f + 0.1f * (float)System.Math.Sin(Timer * 0.6f);
			Main.EntitySpriteDraw(glow, ground, null, Glow(BeamOuter, 0.8f * power), 0f, glow.Size() / 2f, new Vector2(5f, 1.6f) * power * pulse, SpriteEffects.None, 0);
			Main.EntitySpriteDraw(glow, ground, null, Glow(BeamMid, 0.9f * power), 0f, glow.Size() / 2f, new Vector2(3f, 1.2f) * power * pulse, SpriteEffects.None, 0);
			Main.EntitySpriteDraw(glow, ground, null, Glow(Color.White, power), 0f, glow.Size() / 2f, 1.3f * power * pulse, SpriteEffects.None, 0);

			// Two expanding shockwave rings right after the beam hits.
			int t = Timer - LockOnTime;
			for (int i = 0; i < 2; i++) {
				int rt = t - i * 8;
				if (rt >= 0 && rt < 30) {
					float p = rt / 30f;
					Main.EntitySpriteDraw(ring, ground, null, Glow(BeamMid, 1f - p), 0f, ring.Size() / 2f, new Vector2(1f, 0.35f) * (0.5f + p * 4f), SpriteEffects.None, 0);
				}
			}
		}

		private static void DrawBeamLayer(Texture2D beam, Vector2 top, Vector2 origin, float width, float length, Color color) {
			Vector2 scale = new Vector2(width / beam.Width, length / beam.Height);
			Main.EntitySpriteDraw(beam, top, null, color, 0f, origin, scale, SpriteEffects.None, 0);
		}
	}
}
