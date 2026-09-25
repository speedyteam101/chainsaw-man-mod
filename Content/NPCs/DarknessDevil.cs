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
	// Post-Moon Lord boss, one of the Primal Fears. Everyone nearby is constantly in darkness.
	// It drifts after the player and cycles through: hands of darkness that rise under the player,
	// rings of shadow bolts, and vanishing to reappear behind the player. Faster and denser below half health.
	[AutoloadBossHead]
	public class DarknessDevil : ModNPC
	{
		private const int FrameCount = 4;

		private const int StateDrift = 0;
		private const int StateHands = 1;
		private const int StateBurst = 2;
		private const int StateVanish = 3;

		private ref float Timer => ref NPC.ai[0];
		private ref float State => ref NPC.ai[1];
		private ref float NextAttack => ref NPC.ai[2];

		private bool PhaseTwo => NPC.life < NPC.lifeMax / 2;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.MPAllowedEnemies[Type] = true;
			NPCID.Sets.BossBestiaryPriority.Add(Type);
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Confused] = true;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.OnFire] = true;
		}

		public override void SetDefaults() {
			NPC.width = 90;
			NPC.height = 130;
			NPC.damage = 110;
			NPC.defense = 70;
			NPC.lifeMax = 120000;
			NPC.HitSound = SoundID.NPCHit5;
			NPC.DeathSound = SoundID.NPCDeath6;
			NPC.knockBackResist = 0f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.value = Item.buyPrice(gold: 60);
			NPC.SpawnWithHigherTime(30);
			NPC.boss = true;
			NPC.npcSlots = 15f;
			NPC.aiStyle = -1;

			if (!Main.dedServ) {
				Music = MusicID.OtherworldlyBoss1;
			}
		}

		public override void AI() {
			if (NPC.target < 0 || NPC.target == 255 || Main.player[NPC.target].dead || !Main.player[NPC.target].active) {
				NPC.TargetClosest();
			}
			Player player = Main.player[NPC.target];

			if (player.dead) {
				NPC.alpha = System.Math.Min(255, NPC.alpha + 4);
				NPC.velocity *= 0.9f;
				NPC.EncourageDespawn(10);
				return;
			}

			// Darkness aura on every nearby player (each client applies it to its own player).
			if (Main.netMode != NetmodeID.Server) {
				Player local = Main.LocalPlayer;
				if (!local.dead && Vector2.Distance(local.Center, NPC.Center) < 2000f) {
					local.AddBuff(BuffID.Darkness, 30);
				}
			}

			NPC.direction = NPC.spriteDirection = player.Center.X > NPC.Center.X ? 1 : -1;
			NPC.dontTakeDamage = State == StateVanish && Timer < 40;
			Timer++;

			switch ((int)State) {
				case StateDrift:
					Drift(player);
					break;
				case StateHands:
					Hands(player);
					break;
				case StateBurst:
					Burst(player);
					break;
				case StateVanish:
					Vanish(player);
					break;
			}

			if (Main.rand.NextBool(2)) {
				Dust dust = Dust.NewDustDirect(NPC.position, NPC.width, NPC.height, DustID.Smoke, 0f, -1f, 150, Color.Black, 1.6f);
				dust.noGravity = true;
			}
		}

		private void Drift(Player player) {
			NPC.alpha = System.Math.Max(0, NPC.alpha - 10);
			DevilUtils.FlyToward(NPC, player.Center + new Vector2(0f, -120f), PhaseTwo ? 7f : 5f, 30f);
			if (Timer >= (PhaseTwo ? 60 : 90)) {
				int[] order = { StateHands, StateBurst, StateVanish };
				SetState(order[(int)NextAttack % order.Length]);
				NextAttack++;
			}
		}

		private void Hands(Player player) {
			NPC.velocity *= 0.9f;
			if (Timer == 10) {
				SoundEngine.PlaySound(SoundID.Roar, NPC.Center);
				int count = PhaseTwo ? 6 : 4;
				for (int i = 0; i < count; i++) {
					float offset = (i - (count - 1) / 2f) * 80f + player.velocity.X * 25f;
					// Centred on the point, so lift by half the hand's height to stand on the player's feet level.
					DevilUtils.Shoot(NPC, player.Bottom + new Vector2(offset, -45f), Vector2.Zero, ModContent.ProjectileType<DarkHand>(), NPC.damage / 3);
				}
			}
			if (Timer >= 90) {
				SetState(StateDrift);
			}
		}

		private void Burst(Player player) {
			NPC.velocity *= 0.9f;
			int bursts = PhaseTwo ? 3 : 2;
			if (Timer % 30 == 15 && Timer < 30 * bursts) {
				int bolts = PhaseTwo ? 20 : 14;
				float offset = Timer * 0.3f;
				for (int i = 0; i < bolts; i++) {
					Vector2 velocity = (offset + MathHelper.TwoPi * i / bolts).ToRotationVector2() * 8f;
					DevilUtils.Shoot(NPC, NPC.Center, velocity, ModContent.ProjectileType<DarkBolt>(), NPC.damage / 3);
				}
				SoundEngine.PlaySound(SoundID.Item8, NPC.Center);
			}
			if (Timer >= 30 * bursts + 20) {
				SetState(StateDrift);
			}
		}

		private void Vanish(Player player) {
			NPC.velocity *= 0.8f;
			if (Timer < 40) {
				NPC.alpha = System.Math.Min(255, NPC.alpha + 8); // fade out
			}
			if (Timer == 40 && Main.netMode != NetmodeID.MultiplayerClient) {
				// Reappear behind the player.
				NPC.Center = player.Center + new Vector2(-player.direction * 250f, -60f);
				NPC.velocity = Vector2.Zero;
				NPC.netUpdate = true;
			}
			if (Timer > 40) {
				NPC.alpha = System.Math.Max(0, NPC.alpha - 20);
			}
			if (Timer == 60) {
				// Lunge at the player as it reappears.
				NPC.velocity = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitX) * (PhaseTwo ? 20f : 16f);
			}
			if (Timer >= 90) {
				SetState(StateDrift);
			}
		}

		private void SetState(int state) {
			State = state;
			Timer = 0f;
			NPC.netUpdate = true;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 8) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override bool CanHitPlayer(Player target, ref int cooldownSlot) {
			cooldownSlot = ImmunityCooldownID.Bosses;
			return NPC.alpha < 150; // can't hit you while faded out
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ItemID.LunarBar, 1, 15, 25));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 40, 60));
			npcLoot.Add(ItemDropRule.Common(ItemID.SoulofNight, 1, 20, 30));
		}

		public override void BossLoot(ref int potionType) {
			potionType = ItemID.SuperHealingPotion;
		}

		public override void OnKill() {
			NPC.SetEventFlagCleared(ref DownedDevilSystem.downedDarknessDevil, -1);
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new MoonLordPortraitBackgroundProviderBestiaryInfoElement(),
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.DarknessDevil")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit, DustID.Smoke);
		}
	}
}
