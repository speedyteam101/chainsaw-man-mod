using ChainsawManMod.Common.Systems;
using ChainsawManMod.Content.Items;
using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.Audio;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Post-Plantera boss. Strafes around the player with rapid gunfire, then stops to fire a bullet spiral,
	// then charges. Below half health everything is faster and it calls Gun Devil Spawn.
	[AutoloadBossHead]
	public class GunDevil : ModNPC
	{
		private const int FrameCount = 4;
		private const int MaxSpawn = 4;

		private const int StateStrafe = 0;
		private const int StateSpiral = 1;
		private const int StateCharge = 2;

		private ref float Timer => ref NPC.ai[0];
		private ref float State => ref NPC.ai[1];
		private ref float ChargesLeft => ref NPC.ai[2];
		private ref float SpawnTimer => ref NPC.ai[3];

		private bool PhaseTwo => NPC.life < NPC.lifeMax / 2;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.MPAllowedEnemies[Type] = true;
			NPCID.Sets.BossBestiaryPriority.Add(Type);
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Confused] = true;
		}

		public override void SetDefaults() {
			NPC.width = 110;
			NPC.height = 110;
			NPC.damage = 90;
			NPC.defense = 45;
			NPC.lifeMax = 55000;
			NPC.HitSound = SoundID.NPCHit2;
			NPC.DeathSound = SoundID.NPCDeath7;
			NPC.knockBackResist = 0f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.value = Item.buyPrice(gold: 30);
			NPC.SpawnWithHigherTime(30);
			NPC.boss = true;
			NPC.npcSlots = 10f;
			NPC.aiStyle = -1;

			if (!Main.dedServ) {
				Music = MusicID.Boss4;
			}
		}

		public override void AI() {
			if (NPC.target < 0 || NPC.target == 255 || Main.player[NPC.target].dead || !Main.player[NPC.target].active) {
				NPC.TargetClosest();
			}
			Player player = Main.player[NPC.target];

			if (player.dead) {
				NPC.velocity.Y -= 0.3f;
				NPC.EncourageDespawn(10);
				return;
			}

			NPC.direction = NPC.spriteDirection = player.Center.X > NPC.Center.X ? 1 : -1;
			Timer++;

			switch ((int)State) {
				case StateStrafe:
					Strafe(player);
					break;
				case StateSpiral:
					Spiral();
					break;
				case StateCharge:
					Charge(player);
					break;
			}

			if (PhaseTwo) {
				SpawnTimer++;
				if (SpawnTimer >= 480) {
					SpawnTimer = 0f;
					if (DevilUtils.CountActive(ModContent.NPCType<GunDevilSpawn>()) < MaxSpawn) {
						DevilUtils.SpawnMinion(NPC, ModContent.NPCType<GunDevilSpawn>(), NPC.Center);
						DevilUtils.SpawnMinion(NPC, ModContent.NPCType<GunDevilSpawn>(), NPC.Center);
					}
				}
			}

			NPC.rotation = NPC.velocity.X * 0.015f;
		}

		private void Strafe(Player player) {
			// Circle the player at a distance.
			float angle = Timer / 60f;
			Vector2 target = player.Center + new Vector2((float)System.Math.Cos(angle) * 420f, -220f + (float)System.Math.Sin(angle * 2f) * 80f);
			DevilUtils.FlyToward(NPC, target, PhaseTwo ? 16f : 13f, 15f);

			int fireRate = PhaseTwo ? 5 : 8;
			if (Timer % fireRate == 0) {
				Vector2 aim = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY).RotatedByRandom(MathHelper.ToRadians(6f)) * 14f;
				DevilUtils.Shoot(NPC, NPC.Center, aim, ModContent.ProjectileType<DevilBullet>(), NPC.damage / 3);
				SoundEngine.PlaySound(SoundID.Item11, NPC.Center);
			}

			if (Timer >= 240) {
				SetState(StateSpiral);
			}
		}

		private void Spiral() {
			NPC.velocity *= 0.9f;

			if (Timer % 4 == 0) {
				int arms = PhaseTwo ? 4 : 3;
				for (int i = 0; i < arms; i++) {
					float angle = Timer * 0.12f + MathHelper.TwoPi * i / arms;
					DevilUtils.Shoot(NPC, NPC.Center, angle.ToRotationVector2() * 8f, ModContent.ProjectileType<DevilBullet>(), NPC.damage / 3);
				}
				SoundEngine.PlaySound(SoundID.Item11, NPC.Center);
			}

			if (Timer >= 180) {
				SetState(StateCharge);
				ChargesLeft = 3;
			}
		}

		private void Charge(Player player) {
			// 30 ticks aiming, 30 ticks charging, repeated.
			if (Timer == 1) {
				NPC.velocity *= 0.2f;
			}
			if (Timer == 30) {
				SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
				NPC.velocity = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY) * (PhaseTwo ? 28f : 22f);
				NPC.netUpdate = true;
			}
			if (Timer >= 60) {
				ChargesLeft--;
				if (ChargesLeft > 0) {
					Timer = 0f;
					NPC.netUpdate = true;
				}
				else {
					SetState(StateStrafe);
				}
			}
		}

		private void SetState(int state) {
			State = state;
			Timer = 0f;
			NPC.netUpdate = true;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 6) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override bool CanHitPlayer(Player target, ref int cooldownSlot) {
			cooldownSlot = ImmunityCooldownID.Bosses;
			return true;
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<GunDevilFragment>(), 1, 20, 35));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 30, 50));
			npcLoot.Add(ItemDropRule.Common(ItemID.ChlorophyteBar, 1, 15, 25));
		}

		public override void BossLoot(ref int potionType) {
			potionType = ItemID.GreaterHealingPotion;
		}

		public override void OnKill() {
			NPC.SetEventFlagCleared(ref DownedDevilSystem.downedGunDevil, -1);
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new MoonLordPortraitBackgroundProviderBestiaryInfoElement(),
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.GunDevil")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
