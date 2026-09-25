using ChainsawManMod.Content.Items;
using Microsoft.Xna.Framework;
using System;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs.Horde
{
	public enum DevilKind
	{
		Walker,  // walks and jumps like a skeleton
		Flyer,   // hovers near the player
		Swimmer  // swims through blocks, water and air, circling and lunging
	}

	// Shared template for the smaller devils. A subclass sets its numbers, where it spawns, and optionally a shot.
	// Sprites are 4 vertical frames, facing LEFT like vanilla enemies.
	public abstract class DevilEnemyBase : ModNPC
	{
		private const int FrameCount = 4;

		protected abstract DevilKind Kind { get; }
		protected abstract int Life { get; }
		protected abstract int Damage { get; }
		protected abstract int Defense { get; }
		protected virtual int Width => 30;
		protected virtual int Height => 30;
		protected virtual float Speed => 5f;                 // flyers and swimmers
		protected virtual float KnockbackResist => 0.4f;
		protected virtual bool ThroughWalls => false;          // flyers only; swimmers always go through walls
		protected virtual float HoverHeight => 140f;           // flyers: how far above the player they hover
		protected virtual int ContactDebuff => -1;
		protected virtual int DustType => DustID.Blood;
		protected virtual int ShotType => -1;                  // a DevilShotBase projectile, or -1 for none
		protected virtual int ShotRate => 120;
		protected virtual float ShotSpeed => 9f;
		protected virtual int ShotCount => 1;
		protected virtual float ShotSpreadDegrees => 10f;
		protected virtual int ExtraDrop => -1;                 // an extra item, dropped 1 in ExtraDropChance
		protected virtual int ExtraDropChance => 3;
		protected virtual int FleshMin => 1;
		protected virtual int FleshMax => 3;
		protected virtual bool LavaImmune => false;

		private ref float ShotTimer => ref NPC.localAI[0];
		private ref float MoveTimer => ref NPC.localAI[1];

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = Width;
			NPC.height = Height;
			NPC.damage = Damage;
			NPC.defense = Defense;
			NPC.lifeMax = Life;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath1;
			NPC.value = Life * 2f;
			NPC.knockBackResist = KnockbackResist;
			NPC.lavaImmune = LavaImmune;

			if (Kind == DevilKind.Walker) {
				NPC.aiStyle = NPCAIStyleID.Fighter;
				AIType = NPCID.Skeleton;
			}
			else {
				NPC.aiStyle = -1;
				NPC.noGravity = true;
				NPC.noTileCollide = Kind == DevilKind.Swimmer || ThroughWalls;
			}
		}

		public override void AI() {
			NPC.TargetClosest(Kind == DevilKind.Walker);
			Player player = Main.player[NPC.target];
			MoveTimer++;

			if (Kind == DevilKind.Flyer) {
				Vector2 target = player.Center + new Vector2((float)Math.Sin(MoveTimer / 50f) * 160f, -HoverHeight);
				DevilUtils.FlyToward(NPC, target, Speed, 25f);
				if (NPC.collideX) {
					NPC.velocity.X = -NPC.oldVelocity.X * 0.6f;
				}
				if (NPC.collideY) {
					NPC.velocity.Y = -NPC.oldVelocity.Y * 0.6f;
				}
				NPC.direction = player.Center.X > NPC.Center.X ? 1 : -1;
			}
			else if (Kind == DevilKind.Swimmer) {
				if (MoveTimer % 120 == 90) {
					NPC.velocity = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitX) * Speed * 2.2f; // lunge
				}
				else if (MoveTimer % 120 < 90) {
					Vector2 target = player.Center + new Vector2((float)Math.Cos(MoveTimer / 20f) * 160f, 80f);
					DevilUtils.FlyToward(NPC, target, Speed, 25f);
				}
				NPC.direction = NPC.velocity.X > 0 ? 1 : -1;
				NPC.rotation = NPC.velocity.ToRotation() + (NPC.direction == 1 ? 0f : MathHelper.Pi);
				if (Collision.SolidCollision(NPC.position, NPC.width, NPC.height) && Main.rand.NextBool(3)) {
					Dust.NewDust(NPC.position, NPC.width, NPC.height, DustType);
				}
			}

			if (ShotType >= 0) {
				ShotTimer++;
				if (ShotTimer >= ShotRate && Collision.CanHit(NPC.Center, 1, 1, player.Center, 1, 1)) {
					ShotTimer = 0f;
					Vector2 aim = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY);
					for (int i = 0; i < ShotCount; i++) {
						float angle = MathHelper.ToRadians(ShotSpreadDegrees * (i - (ShotCount - 1) / 2f));
						DevilUtils.Shoot(NPC, NPC.Center, aim.RotatedBy(angle) * ShotSpeed, ShotType, NPC.damage / 3);
					}
				}
			}

			NPC.spriteDirection = NPC.direction;
		}

		public override void FindFrame(int frameHeight) {
			if (Kind == DevilKind.Walker) {
				if (NPC.velocity.Y != 0f) {
					NPC.frame.Y = frameHeight;
					return;
				}
				NPC.frameCounter += Math.Abs(NPC.velocity.X) + 0.15f;
			}
			else {
				NPC.frameCounter += 1;
			}
			if (NPC.frameCounter >= 6) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo hurtInfo) {
			if (ContactDebuff >= 0) {
				target.AddBuff(ContactDebuff, 240);
			}
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, FleshMin, FleshMax));
			if (ExtraDrop >= 0) {
				npcLoot.Add(ItemDropRule.Common(ExtraDrop, ExtraDropChance));
			}
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary." + Name)]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit, DustType);
		}
	}
}
