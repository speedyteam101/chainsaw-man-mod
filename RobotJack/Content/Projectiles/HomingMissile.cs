using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Projectiles
{
	// Micro-missile from Missile Barrage. Flies out for a moment, then homes in on the nearest enemy
	// and explodes on contact (with enemies or blocks), damaging everything nearby.
	public class HomingMissile : ModProjectile
	{
		private const int LaunchTicks = 15;
		private const float Speed = 13f;
		private const int ExplosionSize = 90;

		private ref float Timer => ref Projectile.ai[0];

		public override void SetDefaults() {
			Projectile.width = 10;
			Projectile.height = 10;
			Projectile.friendly = true;
			Projectile.DamageType = DamageClass.Ranged;
			Projectile.penetrate = -1;
			Projectile.timeLeft = 240;
			Projectile.aiStyle = -1;
			Projectile.usesLocalNPCImmunity = true;
			Projectile.localNPCHitCooldown = -1;
		}

		public override void AI() {
			// Last 3 ticks: the explosion (a bigger invisible hitbox).
			if (Projectile.timeLeft <= 3) {
				if (Projectile.width != ExplosionSize) {
					Projectile.Resize(ExplosionSize, ExplosionSize);
					Projectile.velocity = Vector2.Zero;
					Projectile.alpha = 255;
					Explode();
				}
				return;
			}

			Timer++;
			if (Timer > LaunchTicks) {
				NPC target = FindTarget(900f);
				if (target != null) {
					Vector2 desired = (target.Center - Projectile.Center).SafeNormalize(Vector2.UnitY) * Speed;
					Projectile.velocity = Vector2.Lerp(Projectile.velocity, desired, 0.12f);
				}
				else if (Projectile.velocity.Length() < Speed) {
					Projectile.velocity *= 1.05f;
				}
			}
			else {
				Projectile.velocity *= 0.96f; // ease out of the launch pods before homing
			}

			Projectile.rotation = Projectile.velocity.ToRotation() + MathHelper.PiOver2;

			// Exhaust flame and smoke.
			Vector2 back = Projectile.Center - Projectile.velocity.SafeNormalize(Vector2.Zero) * 8f;
			Dust fire = Dust.NewDustPerfect(back, DustID.Torch, -Projectile.velocity * 0.2f, Scale: 1.2f);
			fire.noGravity = true;
			if (Main.rand.NextBool(2)) {
				Dust.NewDustPerfect(back, DustID.Smoke, -Projectile.velocity * 0.05f, 150, default, 0.9f).noGravity = true;
			}
			Lighting.AddLight(Projectile.Center, 0.7f, 0.4f, 0.1f);
		}

		private NPC FindTarget(float maxDistance) {
			NPC best = null;
			float bestDist = maxDistance;
			for (int i = 0; i < Main.maxNPCs; i++) {
				NPC npc = Main.npc[i];
				if (!npc.CanBeChasedBy(Projectile)) {
					continue;
				}
				float dist = Vector2.Distance(npc.Center, Projectile.Center);
				if (dist < bestDist) {
					bestDist = dist;
					best = npc;
				}
			}
			return best;
		}

		private void StartExplosion() {
			if (Projectile.timeLeft > 3) {
				Projectile.timeLeft = 3;
			}
		}

		public override void OnHitNPC(NPC target, NPC.HitInfo hit, int damageDone) {
			target.AddBuff(BuffID.OnFire, 180);
			StartExplosion();
		}

		public override bool OnTileCollide(Vector2 oldVelocity) {
			StartExplosion();
			Projectile.velocity = Vector2.Zero;
			return false;
		}

		private void Explode() {
			SoundEngine.PlaySound(SoundID.Item14, Projectile.Center);
			for (int i = 0; i < 20; i++) {
				Dust.NewDustPerfect(Projectile.Center, DustID.Torch, Main.rand.NextVector2Circular(6f, 6f), Scale: 2f).noGravity = true;
			}
			for (int i = 0; i < 10; i++) {
				Dust.NewDustPerfect(Projectile.Center, DustID.Smoke, Main.rand.NextVector2Circular(3f, 3f), 100, default, 1.6f);
			}
		}

		public override bool PreDraw(ref Color lightColor) {
			if (Projectile.alpha >= 255) {
				return false; // the explosion itself is only dust
			}
			Texture2D tex = TextureAssets.Projectile[Type].Value;
			Main.EntitySpriteDraw(tex, Projectile.Center - Main.screenPosition, null, lightColor, Projectile.rotation, tex.Size() / 2f, 1f, SpriteEffects.None, 0);
			return false;
		}
	}
}
